import uuid
from datetime import UTC, date, datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core.deps import Principal, require_patient
from app.db import get_session
from app.models import ExtractionJob, ExtractionStatus, Patient, Record
from app.schemas.record import (
    ConfirmRequest,
    ExtractionView,
    ExtractResult,
    RecordData,
    RecordDetail,
    RecordSummary,
    SensitiveRequest,
    UploadResult,
)
from app.services import extraction as extraction_svc
from app.services.patients import resolve_patient
from app.services.storage import extension_for, get_storage, guess_media_type

router = APIRouter(prefix="/records", tags=["records"])
_settings = get_settings()
_MAX_BYTES = 12 * 1024 * 1024


async def _owned_record(session: AsyncSession, principal: Principal, record_id: str) -> Record:
    try:
        pk = uuid.UUID(record_id)
    except ValueError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Record not found") from exc
    record = await session.get(Record, pk)
    if record is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Record not found")
    # ownership: the record's patient must be the caller or their minor
    me = (
        await session.execute(
            select(Patient).where(
                Patient.user_id == principal.user_id, Patient.guardian_patient_id.is_(None)
            )
        )
    ).scalar_one_or_none()
    if me is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Patient profile missing")
    owner = await session.get(Patient, record.patient_id)
    if owner.id != me.id and owner.guardian_patient_id != me.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your record")
    return record


def _extraction_view(job: ExtractionJob | None) -> ExtractionView | None:
    if job is None:
        return None
    return ExtractionView(
        job_id=str(job.id),
        status=job.status,
        confidence_by_field=job.confidence_by_field or {},
        error=job.error,
    )


@router.post("/upload", response_model=UploadResult, status_code=status.HTTP_201_CREATED)
async def upload(
    file: UploadFile = File(...),
    patient_id: str | None = Form(default=None),
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> UploadResult:
    patient = await resolve_patient(session, principal.user_id, patient_id)
    blob = await file.read()
    if not blob:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Empty file")
    if len(blob) > _MAX_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "File too large (max 12 MB)")
    try:
        media_type = guess_media_type(file.filename or "upload", file.content_type)
    except ValueError as exc:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, str(exc)) from exc

    record = Record(patient_id=patient.id, type="note", data={}, verified=False)
    session.add(record)
    await session.flush()

    key = f"{patient.id}/{record.id}{extension_for(media_type)}"
    get_storage().put(key, blob, media_type)
    record.source_object_key = key
    await session.commit()
    return UploadResult(record_id=str(record.id), type=record.type)


@router.post("/{record_id}/extract", response_model=ExtractResult)
async def extract(
    record_id: str,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> ExtractResult:
    record = await _owned_record(session, principal, record_id)
    if record.source_object_key is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Nothing uploaded for this record")
    if record.verified:
        raise HTTPException(status.HTTP_409_CONFLICT, "Record already confirmed")

    job = ExtractionJob(
        patient_id=record.patient_id,
        record_id=record.id,
        status=ExtractionStatus.running.value,
    )
    session.add(job)
    await session.flush()

    blob = get_storage().get_bytes(record.source_object_key)
    media_type = guess_media_type(record.source_object_key, None)
    try:
        raw = await extraction_svc.extract_document(blob, media_type)
        rtype, doc_date, provider, data, confidence = extraction_svc.normalise(raw)
    except Exception as exc:  # noqa: BLE001 — surface any model/parse failure to the user
        job.status = ExtractionStatus.failed.value
        job.error = str(exc)[:500]
        await session.commit()
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Extraction failed: {exc}") from exc

    job.status = ExtractionStatus.needs_review.value
    job.raw_model_output = raw
    job.confidence_by_field = confidence
    record.type = rtype
    record.provider = provider
    record.doc_date = date.fromisoformat(doc_date) if doc_date else None
    record.data = data.model_dump()
    record.extraction_job_id = job.id
    await session.commit()

    return ExtractResult(
        record_id=str(record.id),
        extraction=_extraction_view(job),
        draft=data,
    )


@router.post("/{record_id}/confirm", response_model=RecordDetail)
async def confirm(
    record_id: str,
    body: ConfirmRequest,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> RecordDetail:
    record = await _owned_record(session, principal, record_id)
    if body.type:
        record.type = body.type
    record.doc_date = body.doc_date
    record.provider = body.provider
    record.data = body.data.model_dump()
    record.verified = True
    record.verified_by = principal.user_id
    record.verified_at = datetime.now(UTC)
    job = None
    if record.extraction_job_id:
        job = await session.get(ExtractionJob, record.extraction_job_id)
        if job is not None:
            job.status = ExtractionStatus.confirmed.value
    await session.commit()
    return await _detail(record, job)


@router.post("/{record_id}/sensitive", response_model=RecordDetail)
async def set_sensitive(
    record_id: str,
    body: SensitiveRequest,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> RecordDetail:
    record = await _owned_record(session, principal, record_id)
    record.sensitive = body.sensitive
    await session.commit()
    job = (
        await session.get(ExtractionJob, record.extraction_job_id)
        if record.extraction_job_id
        else None
    )
    return await _detail(record, job)


@router.get("", response_model=list[RecordSummary])
async def list_records(
    patient_id: str | None = None,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> list[RecordSummary]:
    patient = await resolve_patient(session, principal.user_id, patient_id)
    rows = (
        await session.execute(
            select(Record)
            .where(Record.patient_id == patient.id)
            .order_by(Record.doc_date.is_(None), Record.doc_date.desc(), Record.created_at.desc())
        )
    ).scalars().all()
    return [
        RecordSummary(
            record_id=str(r.id),
            type=r.type,
            doc_date=r.doc_date,
            provider=r.provider,
            verified=r.verified,
            sensitive=r.sensitive,
            created_at=r.created_at,
        )
        for r in rows
    ]


@router.get("/{record_id}", response_model=RecordDetail)
async def get_record(
    record_id: str,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> RecordDetail:
    record = await _owned_record(session, principal, record_id)
    job = (
        await session.get(ExtractionJob, record.extraction_job_id)
        if record.extraction_job_id
        else None
    )
    return await _detail(record, job)


@router.get("/_local-object/{key:path}")
async def local_object(
    key: str,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> Response:
    """Dev-only object read for the local storage backend."""
    if _settings.storage_backend != "local":
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Not found")
    record = (
        await session.execute(select(Record).where(Record.source_object_key == key))
    ).scalar_one_or_none()
    if record is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Not found")
    await _owned_record(session, principal, str(record.id))
    blob = get_storage().get_bytes(key)
    return Response(content=blob, media_type=guess_media_type(key, None))


async def _detail(record: Record, job: ExtractionJob | None) -> RecordDetail:
    source_url = (
        get_storage().presigned_url(record.source_object_key)
        if record.source_object_key
        else None
    )
    return RecordDetail(
        record_id=str(record.id),
        type=record.type,
        doc_date=record.doc_date,
        provider=record.provider,
        verified=record.verified,
        sensitive=record.sensitive,
        created_at=record.created_at,
        data=RecordData.model_validate(record.data or {}),
        source_url=source_url,
        extraction=_extraction_view(job),
    )
