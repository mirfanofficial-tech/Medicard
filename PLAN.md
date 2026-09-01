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

### Phase 0 — Setup (Day 1)  ✔ done
- Repo layout: `backend/` (FastAPI) + `app/` (Flutter) + `docker-compose.yml` (Postgres + MinIO).
- Backend: uv project, FastAPI app skeleton, config, async DB session, Alembic, health endpoint,
  pytest wired.
- Flutter: scaffold, Riverpod + go_router + dio, theme (verified = green accent, unverified = amber
  tag), role-selection landing screen.
- `flutter analyze` / `ruff` / `pytest` all green on an empty slice.

### Phase 1 — Identity & access accounts (Days 2–3)  ✔ backend + app flows done
- Patient signup: phone OTP + name + optional CNIC → generate `medicard_code` (8-char Crockford
  base32 + checksum). ✔ QR rendering deferred to Phase 3 (doctor scan).
- Doctor signup: email/password (Argon2) + licence no + specialty + hospital →
  `status: pending_verification`; `require_active_doctor` blocks record search until approved. ✔
- Admin review queue: `GET /admin/doctors`, `POST /admin/doctors/{id}/review` behind `X-Admin-Key`.
  ✔ (a small admin web screen is still a nice-to-have; console/curl works now.)
- Guardian flow: `POST /patient/minors`, `GET /patient/profiles`. ✔
- Recovery: `POST /auth/patient/recover/{request,verify}` re-verifies phone OTP (+ CNIC hash match
  if on file) and reissues the code on the **same** profile. ✔
- App: role-select → patient OTP screen / doctor register+login screen → home screens showing the
  MediCard code and the doctor verification banner; token refresh + secure storage wired.
- Endpoints proven end-to-end over HTTP; `pytest` (14) + `ruff` + `flutter analyze` + `flutter
  test` (3) all green. Initial Alembic migration `0001_initial` verified up+down.

### Phase 2 — Records: upload → AI extraction → confirmation (Days 3–5)  ✔ done
- Upload screen: camera / gallery / PDF picker → `POST /records/upload` → storage (MinIO in prod;
  local-fs backend for dev/tests). 12 MB cap, JPEG/PNG/PDF only. ✔
- `POST /records/{id}/extract`: sends the file to `claude-sonnet-5` as an `image`/`document` block,
  parses a strict JSON schema (`type`, `doc_date`, `provider`, `data{…}`, `confidence_by_field`
  with dotted paths). Writes an `extraction_job` → `needs_review`; low-confidence fields flagged.
  `FAKE_EXTRACTION` / missing key → deterministic stub so the flow runs offline. ✔
- **Extraction review screen:** amber "nothing saved yet" banner; every section editable
  (diagnoses / medications / labs / allergies / notes); low-confidence fields carry a "please
  check" chip. "Confirm & save as verified" writes the canonical record (`verified: true`,
  `verified_by`, `verified_at`) and closes the job. ✔
- Timeline: reverse-chronological, per-type icons, `ProvenanceTag` (green Verified / amber
  Unverified) on every row, hidden-by-default marker. Record detail shows the data, a
  hidden-by-default toggle (`sensitive`), and the source object URL. ✔
- Guardrails: extraction runs only in the backend; the system prompt forbids inferring diagnoses
  or doses and requires low-confidence marking; no record is canonical without a human confirm.
- Backend `pytest` 19, `ruff` clean, migration `0002_records` verified up+down, full flow
  smoke-tested over HTTP. App `flutter analyze` + `flutter test` (3) green.
- Deferred: image compression before upload, type filters on the timeline, presigned-URL image
  preview widget (URL is returned, not yet rendered).

### Phase 3 — Consent-gated doctor access (Days 5–7)  ✔ done
- Doctor enters code → `POST /doctor/access-requests` (active doctors only) → patient notified
  (FCM stub — logs; device-token registry still TODO) and sees it in Pending. ✔
- Patient approve/deny → on approve, `access_grant` (`scope: full`, `expires_at` = now + 12h) +
  `audit_log` `grant`. Deny logs `deny`. ✔
- `GET /doctor/patients/{id}/records` (+ `/records/{rid}`) require a live full grant, exclude
  `sensitive` records entirely, and write an `audit_log` `view` row in the same commit. ✔
- **Break-glass:** `POST /doctor/break-glass` {code, reason} (reason required) → immediate
  `scope: critical`, `source: break_glass`, short TTL grant → returns the aggregated critical
  subset (allergies, current meds from prescriptions, conditions) → `audit_log` `break_glass`
  with the reason → patient notified. Critical scope cannot open the full timeline. ✔
- `GET /doctor/patients/{id}/critical` works under either scope. Doctor can `end` a grant early;
  patient can `revoke` any grant (`audit_log` `end` / `revoke`). ✔
- **App:** doctor "Access a patient record" hub (code entry, emergency dialog, live grants list
  with Open/End); doctor patient-timeline + record detail + red critical-summary screen; patient
  "Access requests" (approve/deny) and "Access history" (active grants with Revoke + full audit
  log). ✔
- Backend `pytest` 27 (8 access scenarios: no-grant/denied/expired/ended/revoked 403s, scoped
  read, break-glass critical-only + logging, reason required). `ruff` clean. Migration
  `0003_access` verified up+down. Full flow smoke-tested over HTTP. `flutter analyze` + tests (3).
- Deferred: real FCM device registration; QR scan (code is typed); guardian-approves-minor is
  wired server-side but has no dedicated app screen yet.

### Phase 4 — AI clinical support (Days 7–9)  ✔ done
- `GET /doctor/patients/{id}/ai-summary` (live full grant) → `claude-sonnet-5` over the shared
  records. System prompt: summarise + flag only; **never** recommend starting/stopping/changing a
  medication or pair a drug with a dose as an action; no diagnosis not already in the record;
  every statement and flag must cite `source_record_ids`. Output
  `{summary, flags:[{text, severity(info|watch|urgent), source_record_ids[]}], relevant_history[],
  model, advisory_notice}`. `FAKE_AI=true` / no key → deterministic stub citing real record ids.
- `POST /doctor/patients/{id}/ai-ask` {question} → answers **only** from the records JSON, cites
  `source_record_ids`, sets `answered_from_records: false` and declines when the answer isn't in
  the record. Both endpoints write an `audit_log` `view` row (`meta.view = ai_summary|ai_ask`).
- App: `AiPanelScreen` — persistent advisory-only banner, summary text, flag cards with a
  severity chip and tappable source chips (→ record detail), grounded Ask box with the same
  source chips and an amber card when the answer is not from the record. Reached from the doctor
  patient-records screen ("AI summary").
- Backend `pytest` 31 (4 AI cases: grant required, flags cite real records + advisory notice,
  Ask grounded on/off-topic). `ruff` clean. Smoke-tested over HTTP. `flutter analyze` + tests (3).

### Phase 5 — Polish, honesty, demo (Days 9–10)  ◑ mostly done
- `python -m app.seed` — idempotent: Dr Sara Ahmed (verified) + Ayesha Khan with 6 records
  (1 sensitive), a rising HbA1c trend and an NSAID-on-ACE-inhibitor combo for the AI to flag.
  Prints the login + MediCard code. ✔
- [DEMO.md](DEMO.md) — one-command startup (SQLite + local storage + stubbed AI, no Docker/key)
  and the 5-minute script. ✔
- [docs/STATUS.md](docs/STATUS.md) — "what's solved / what's not yet / why the AI is advisory",
  doubles as the honesty slide. ✔
- App polish: on-device image downscale+recompress before upload (1600px / q80); timeline
  type-filter chips; the record source photo now renders inline on the patient detail screen. ✔
- Advisory-only banner already persistent on the AI panel (Phase 4).
- **Still open:** offline write queue + text-only mode; QR scan; a guardian-approves-for-minor
  screen; real FCM device registration; Postgres/MinIO run; an Android device build.

### Phase 6 — Prescription assistant (added 2026-09-01)  ✔ done
Requested feature: "when a doctor writes a prescription, AI suggests according to patient history."
Built as the **rubric-safe** version — the doctor authors, the assistant only surfaces what is
already documented and checks the draft; it never proposes a new medicine (see §5).
- `GET /doctor/patients/{id}/prescribe/context` (full grant) → the patient's **current
  medications, taken verbatim from their own prescription records** (deduped, newest first, each
  with `source_record_id`) + `known_allergies`.
- `POST …/prescribe/check` {medications} → a **deterministic rule engine** (no model call):
  allergy conflicts (curated drug-class map), class-pair interactions incl. draft-vs-meds-already-
  on-record, and duplicate-therapy. Severities urgent / watch / info.
- `POST …/prescribe` {medications[], notes?} → creates a `verified` `prescription` `Record`
  (`authored_by_doctor_id`, provider "Dr …"), notifies the patient, writes `audit_log` `prescribe`.
  Guardrail: any line marked `origin: "history"` whose drug isn't in the record → 422.
- Migration `0004_rx_author` (records.authored_by_doctor_id). App: `PrescribeScreen` — allergy
  banner, "from <patient>'s record" checklist that adds ticked lines to the draft, editable draft
  rows + manual add, live checks panel, "you are the prescriber" line. Entry: "Prescribe" on the
  doctor patient-records screen.
- Backend `pytest` 37 (6 new). `ruff` clean. Smoke-tested over HTTP.

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
- **Prescription assistant (Phase 6):** the model is not in the loop at all — the "suggestions"
  are the patient's own recorded medicines (data lookup), and the safety checks are a deterministic
  rule engine. The doctor is the author and is named on the record. Nothing new is ever proposed.
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
