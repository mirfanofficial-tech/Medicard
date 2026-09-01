from __future__ import annotations

import functools
import mimetypes
from pathlib import Path

from app.config import get_settings

_settings = get_settings()

_ALLOWED = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "application/pdf": ".pdf",
}


def guess_media_type(filename: str, given: str | None) -> str:
    if given in _ALLOWED:
        return given
    guessed, _ = mimetypes.guess_type(filename)
    if guessed in _ALLOWED:
        return guessed
    raise ValueError("Only JPEG, PNG, or PDF files are accepted")


def extension_for(media_type: str) -> str:
    return _ALLOWED[media_type]


class Storage:
    """put() an object and mint a short-lived GET url. Backed by MinIO/S3 or the
    local filesystem so dev/tests work without Docker."""

    def put(self, key: str, data: bytes, media_type: str) -> None: ...
    def get_bytes(self, key: str) -> bytes: ...
    def presigned_url(self, key: str, expires_s: int = 600) -> str: ...


class LocalStorage(Storage):
    def __init__(self, root: str) -> None:
        self._root = Path(root)
        self._root.mkdir(parents=True, exist_ok=True)

    def _path(self, key: str) -> Path:
        p = (self._root / key).resolve()
        if not str(p).startswith(str(self._root.resolve())):
            raise ValueError("bad key")
        p.parent.mkdir(parents=True, exist_ok=True)
        return p

    def put(self, key: str, data: bytes, media_type: str) -> None:
        self._path(key).write_bytes(data)

    def get_bytes(self, key: str) -> bytes:
        return self._path(key).read_bytes()

    def presigned_url(self, key: str, expires_s: int = 600) -> str:
        return f"/records/_local-object/{key}"


class S3Storage(Storage):
    def __init__(self) -> None:
        import boto3

        self._bucket = _settings.s3_bucket
        self._client = boto3.client(
            "s3",
            endpoint_url=_settings.s3_endpoint_url,
            aws_access_key_id=_settings.s3_access_key,
            aws_secret_access_key=_settings.s3_secret_key,
            region_name=_settings.s3_region,
        )

    def put(self, key: str, data: bytes, media_type: str) -> None:
        self._client.put_object(Bucket=self._bucket, Key=key, Body=data, ContentType=media_type)

    def get_bytes(self, key: str) -> bytes:
        return self._client.get_object(Bucket=self._bucket, Key=key)["Body"].read()

    def presigned_url(self, key: str, expires_s: int = 600) -> str:
        return self._client.generate_presigned_url(
            "get_object",
            Params={"Bucket": self._bucket, "Key": key},
            ExpiresIn=expires_s,
        )


@functools.lru_cache
def get_storage() -> Storage:
    if _settings.storage_backend == "local":
        return LocalStorage(_settings.storage_local_dir)
    return S3Storage()
