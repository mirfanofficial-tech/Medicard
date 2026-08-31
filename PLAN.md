# MediCard — Implementation Plan

_Shared, patient-controlled medical-record app with AI extraction and AI clinical support._
_Target: working full-stack MVP. Client: Flutter. Backend: FastAPI + Postgres. Timeline: ~1.5–2 weeks. Plan dated 2026-08-31._

**Locked decisions (2026-08-31):** owned FastAPI + Postgres backend · Claude-only multimodal
extraction · manual doctor-review queue · grant lifetime 12h time-boxed + doctor can end early ·
Android-first demo · B2B hospitals as the monetisation wedge.

---

## 1. What we are building (locked scope)

A single Flutter app with two roles:

- **Patient** — owns a MediCard (a code + QR). Uploads paper prescriptions/reports, which AI
  extracts into structured history. Approves or denies each doctor's request to view. Can mark
  entries sensitive. Sees a full access log.
- **Doctor** — registers with a licence number, verified before the account can search. Requests
  access by patient code; on patient approval, sees the history plus an **advisory** AI panel that
  summarises relevant history and flags trends / allergies / possible interactions. Never a
  prescription recommendation.

The design deliberately fixes the six weaknesses identified in the pitch review:

| # | Weakness in original idea | How this plan fixes it |
|---|---|---|
| 1 | AI suggests the next prescription (contradicts the "assist, don't decide" rubric + DRAP risk) | AI is summariser/flagger only. System prompt hard-forbids drug+dose recommendations. Persistent "advisory only — physician retains prescribing authority" banner. |
| 2 | Patient code = skeleton key, permanent, full history | Per-visit **consent gate**: doctor enters code → patient's phone approves → time-boxed, logged grant. **Break-glass** emergency mode returns critical-only data, is logged, and is disclosed to the patient afterward. |
| 3 | Nothing verifies the doctor is a doctor | Licence number (PMDC) captured at signup; account is `pending_verification` and cannot search until cleared (manual review queue for MVP). |
| 4 | Handwriting→data has no safety net | Every extraction goes through a **confirmation screen** with per-field confidence. Nothing is canonical until a human confirms. Verified vs unverified data is visually distinct everywhere. |
| 5 | Regulatory / liability exposure | Treat all health data as sensitive by design. Advisory-only disclaimer in UI and pitch. "Here's what's solved, here's what isn't" honesty slide. |
| 6 | Smaller gaps | Sensitive-entry hiding; grounded AI Q&A with source citations; lost-code recovery tied to phone/CNIC (no profile forking); low-bandwidth mode; guardian-linked minors; B2B-hospital monetisation wedge for the demo. |

---

## 2. Architecture & stack

| Layer | Choice | Notes |
|---|---|---|
| Client | **Flutter** (Android-first for the demo; iOS/web buildable) | One codebase, role chosen at signup, role-gated navigation. Riverpod + go_router + dio. |
| Backend | **FastAPI** (async) + **Postgres** + **MinIO** (S3-compatible object store) | Owned backend. SQLAlchemy 2.0 async + Alembic. Runs via docker-compose in dev. |
| Auth | Own JWT auth. Patients: phone OTP. Doctors: email + password (Argon2). | Access + refresh tokens; phone OTP doubles as patient identity + recovery anchor. |
| AI | **Claude via the Anthropic API**, called only from the backend | `claude-sonnet-5` for extraction and clinical summary. Image + PDF go in as `document` blocks; `citations: {enabled: true}` gives source references for free. Structured outputs (`output_config.format`) for the JSON schemas. Fall back to Google Document AI for OCR only if handwriting accuracy is poor. |
| Push | FCM via `firebase-admin` (server-side only) | Access-request approval prompts. |
| Secrets | Backend `.env` / deploy env | API keys never ship in the app. |

**Security spine:** the doctor app has no endpoint that returns raw patient records. Doctor reads go
through `GET /doctor/patients/{id}/records`, which (a) checks for an active, unexpired grant or a
break-glass entry, (b) strips hidden entries, (c) narrows to critical-only for break-glass, (d)
writes an audit-log row inside the same DB transaction. Row-level checks live in the service layer;
every doctor-facing query is scoped by `grant`.

---

## 3. Data model (Postgres, via SQLAlchemy + Alembic)

```
users            id, role (patient|doctor), created_at
                 -- auth identity; one row per login principal
patients         id, user_id FK, name, dob, phone, cnic_hash?, medicard_code (unique, non-guessable),
                 guardian_patient_id FK?  -- set on minor profiles
doctors          id, user_id FK, name, email, licence_no, specialty, hospital,
                 status (pending_verification|active|rejected)
records          id, patient_id FK, type (prescription|lab|imaging|note), doc_date, provider,
                 data JSONB (diagnoses[], medications[{name,dose,route,freq}],
                             lab_results[{name,value,unit,ref_range}], allergies[]),
                 source_object_key, verified bool, verified_by, verified_at,
                 sensitive bool, extraction_job_id FK
access_requests  id, doctor_id FK, patient_id FK, status (pending|approved|denied|expired), created_at
access_grants    id, doctor_id FK, patient_id FK, scope (full|critical),
                 granted_at, expires_at, ended_at?, source (consent|break_glass), reason?
audit_log        id, actor_id, actor_role, patient_id, action (view|extract|grant|break_glass),
                 scope, at, meta JSONB
extraction_jobs  id, patient_id FK, status (running|needs_review|confirmed|failed),
                 raw_model_output JSONB, confidence_by_field JSONB
otp_challenges   id, phone, code_hash, expires_at, attempts   -- patient phone OTP
```

---

## 4. Build phases

Roughly 8–10 working days. Each phase ends with something demoable.

### Phase 0 — Setup (Day 1)  ← in progress
- Repo layout: `backend/` (FastAPI) + `app/` (Flutter) + `docker-compose.yml` (Postgres + MinIO).
- Backend: uv project, FastAPI app skeleton, config, async DB session, Alembic, health endpoint,
  pytest wired.
- Flutter: scaffold, Riverpod + go_router + dio, theme (verified = green accent, unverified = amber
  tag), role-selection landing screen.
- `flutter analyze` / `ruff` / `pytest` all green on an empty slice.

### Phase 1 — Identity & access accounts (Days 2–3)
- Patient signup: phone OTP + name + DOB + optional CNIC → generate `mediCardCode` (8-char
  Crockford base32 + checksum) and QR.
- Doctor signup: email/password + licence no + specialty + hospital → `status: pending_verification`.
- Admin review screen (or Firebase console + a Function) to flip a doctor to `active`.
- Guardian flow: a patient account can create a linked minor profile.
- Recovery: lost code → re-verify phone OTP (+ CNIC hash match if present) → reissue code on the
  **same** profile. Never create a second profile.

### Phase 2 — Records: upload → AI extraction → confirmation (Days 3–5)
- Upload screen: camera / gallery / PDF picker → compress → `POST /records/upload` → MinIO.
- `POST /records/{id}/extract` (backend): send the file to `claude-sonnet-5` as a `document` block
  with a structured-output schema; return fields + `confidence_by_field`; write an `extraction_job`
  with `status: needs_review`.
- **Extraction review screen:** every field shown with a confidence badge; inline edit; "Confirm"
  writes the canonical `record` with `verified: true`. Unconfirmed data stays `verified: false` and
  renders with an amber "Unverified" tag wherever it appears.
- Patient timeline: chronological records, type filters, sensitive entries collapsed by default with
  tap-to-reveal + confirm.

### Phase 3 — Consent-gated doctor access (Days 5–7)
- Doctor enters code / scans QR → `POST /doctor/access-requests` → FCM push to patient.
- Patient approve/deny screen → on approve, `access_grant` (`scope: full`, `expires_at` = now + 12h;
  doctor can also end early) + `audit_log` row.
- `GET /doctor/patients/{id}/records` enforces the grant, strips `sensitive` entries, logs the view.
- **Break-glass:** doctor toggles "Emergency access", must type a reason → endpoint returns the
  `critical` subset (allergies, blood type, chronic conditions, current meds) → `audit_log` row
  flagged `break_glass` → patient gets a notification and an entry in Access History.
- **Access History screen** (patient): every view — who, when, scope, emergency flag.

### Phase 4 — AI clinical support (Days 7–9)
- Doctor record view → "AI Summary" panel → `GET /doctor/patients/{id}/ai-summary` sends the
  structured records to `claude-sonnet-5`. System prompt constraints:
  - summarise relevant history (conditions, current meds, allergies, trends);
  - flag things worth a second look (rising HbA1c, drug-interaction risk);
  - **never** output a drug name + dose as a recommendation;
  - every statement cites the record it came from.
  - Output schema: `{ summary, flags: [{text, severity, sourceRecordIds[]}], relevantHistory: [...] }`.
- Render flags with source chips ("from Lab Report, 10 May") that deep-link to the record.
- "Ask AI" box: question + this patient's records as the only context; same grounding rules;
  answers only from records; says so when the answer isn't in the records.
- Persistent advisory-only banner on the panel.

### Phase 5 — Polish, honesty, demo (Days 9–10)
- Advisory-only disclaimer in the UI and the pitch deck.
- Low-bandwidth mode: aggressive image compression, text-only timeline toggle, offline write queue.
- Seed a realistic demo patient (diabetes + hypertension, a few labs, an allergy, one sensitive entry).
- "What's solved / what's not yet / our plan" slide.
- Rehearse the demo script (Section 6).

### Cross-cutting — security (throughout)
- Every query in the doctor service layer is scoped by a verified `access_grant`; there is no
  endpoint returning unscoped patient records.
- MinIO objects served only via short-lived pre-signed URLs minted after the same grant check.
- All doctor reads and extractions written to `audit_log` in the same transaction as the read.
- Field-level encryption for `sensitive` records — stretch goal.

---

## 5. AI guardrails (the part a judge will probe)

- Extraction and summary run **only** in the backend; the app holds no API key.
- Summary system prompt forbids prescriptions; we show the prompt in the appendix of the deck.
- Structured outputs + citations mean every AI claim is traceable to a source record; an ungrounded
  answer is a bug, not a feature.
- One sentence, said out loud in the pitch: _"AI output is advisory only — the licensed physician
  retains full prescribing authority and responsibility."_ Doubles as liability and DRAP framing.

---

## 6. Demo script (5 minutes)

1. Patient photographs a handwritten prescription → AI extracts → **confirmation screen**, fix one
   misread dose → saved as verified.
2. Doctor logs in (already verified) → enters the patient's code → patient's phone buzzes →
   **Approve** → doctor sees the timeline.
3. Doctor opens **AI Summary** → "HbA1c rising across 3 visits", "new NSAID + existing ACE
   inhibitor — check renal function", each with a source chip. Point at the advisory-only banner.
4. Patient opens **Access History** → shows exactly what the doctor saw and when.
5. Show **break-glass**: emergency toggle → critical-only view → patient immediately notified.
6. Close on the honesty slide.

---

## 7. Decisions — resolved 2026-08-31

1. **Backend:** owned FastAPI + Postgres. ✔
2. **AI:** Claude-only multimodal extraction; Google Document AI only as a fallback if handwriting
   accuracy disappoints. ✔
3. **Doctor verification:** manual review queue. ✔
4. **Grant lifetime:** 12h time-boxed, and the doctor can end a session early. ✔
5. **Platforms for the demo:** Android-first (web/Windows used during dev). ✔
6. **Monetisation wedge:** B2B hospitals/clinics. ✔
```
