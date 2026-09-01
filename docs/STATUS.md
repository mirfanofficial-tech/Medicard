# MediCard — what's solved, what isn't, what's next

_The brief asked us to be honest about limits. This is that page._

## Solved and working end-to-end

| Area | State |
|---|---|
| Patient identity | Phone-OTP sign-in, MediCard code (Crockford base32 + checksum), guardian-linked minor profiles, lost-code recovery on the **same** profile (phone + CNIC re-check) |
| Doctor identity | Email/password, licence number captured, account is **pending until a reviewer approves it** — an unverified doctor cannot search any record |
| Records | Upload (image/PDF) → AI extraction → **human confirmation screen** with per-field confidence → verified vs unverified shown distinctly everywhere; sensitive entries hidden by default |
| Consent | Doctor requests by code → patient approves on their device → **time-boxed, scoped, logged** grant; doctor or patient can end it early |
| Break-glass | Emergency access = critical fields only (allergies, current meds, conditions), reason required, logged, patient notified, **cannot** open the full record |
| Audit | Every doctor read writes an audit row in the same transaction; patient sees the full history and every active grant |
| AI | Advisory summary + grounded "Ask" — **never** recommends a drug or dose, every claim cites a source record, off-record questions are declined |
| Prescription assistant | Doctor authors the prescription. The assistant pre-fills lines **only from the patient's own recorded medicines** and runs a deterministic allergy / interaction / duplicate-therapy check on the draft. No model is in the loop; nothing new is ever proposed; the doctor is named on the record |

## Not done yet (known gaps)

- **Push notifications** — the server-side hook exists but there's no device-token registry, so
  "the patient's phone buzzes" is currently the pending-requests list, not a real push.
- **QR scanning** — the MediCard code is typed, not scanned.
- **Guardian approving for a minor** — the server enforces it; there's no dedicated app screen.
- **Offline / low-bandwidth** — image compression on upload is in; a full offline write queue and
  a text-only mode are not.
- **Real infra** — everything has run on SQLite + local file storage. The Postgres + MinIO path
  is wired (`infra/docker-compose.yml`, portable migrations) but not yet exercised.
- **Android build** — developed and tested on web/desktop; not yet built against a device.
- **Structured-output hardening** — AI/extraction JSON is parsed from the model text with a
  schema in the prompt; moving to enforced structured outputs is a follow-up.
- **Field-level encryption** for sensitive records — stretch goal, not implemented.

## Why the AI is deliberately advisory

The track's own rubric is "assist, don't decide", with a human review step between AI support and
the next action. An AI that suggests the next prescription skips that step and lands much closer to
"treatment decision support" under DRAP's medical-device definition. Keeping the AI to
summarise-and-flag is both the rubric-safe choice and the lower-liability one — and it's still the
useful part: the physician decides faster, with the whole picture and the risks called out, not
blindly.

The prescription assistant follows the same line. "Suggest according to patient history" is
implemented as: pull up the medicines already documented for this patient so the doctor can renew
them with one tap, and check whatever the doctor drafts for allergy conflicts, interactions and
duplicates. It never introduces a medicine that isn't already in the record, and the checks are a
plain rule engine, not a model. The doctor writes the prescription and is named on it.

## Next

Phase 5 finish (offline queue, QR, guardian screen), then real Postgres/MinIO, then an Android
build and a hardened structured-output path.
