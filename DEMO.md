# MediCard — demo runbook

## Start it

```bash
# backend (SQLite + local storage + stubbed AI — no Docker, no API key needed)
cd backend
export DATABASE_URL="sqlite+aiosqlite:///./demo.db" STORAGE_BACKEND=local \
       FAKE_EXTRACTION=true FAKE_AI=true JWT_SECRET=demo-secret-at-least-32-bytes-long \
       ADMIN_API_KEY=demo-admin
uv run alembic upgrade head
uv run python -m app.seed          # prints the demo credentials + MediCard code
uv run uvicorn app.main:app --port 8000

# app (another shell) — point it at the backend
cd app
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

For a real Claude extraction / summary instead of the stub: drop `FAKE_EXTRACTION` /
`FAKE_AI` and set `ANTHROPIC_API_KEY`.

## Seed accounts (from `python -m app.seed`)

| Who | Sign in with |
|---|---|
| Dr Sara Ahmed (verified) | `demo.doctor@medicard.test` / `demodemo123` |
| Ayesha Khan (patient) | phone `+923001112222` — the OTP is returned in the API response in dev; the app shows it as "Dev code" |
| MediCard code | printed by the seed script (changes each run) |

Ayesha has 6 records, one marked **sensitive** (anxiety note). Her HbA1c rises 7.4 → 8.1 → 8.6
across three visits, and her latest prescription adds **ibuprofen** on top of **ramipril** (an
ACE inhibitor) — both are what the AI summary should flag.

## 5-minute script

1. **Extraction + confirmation.** As Ayesha, "Add a record" → pick any image → the review screen
   shows the extracted fields with low-confidence flags. Correct one dose, **Confirm** → it lands
   on the timeline with a green **Verified** tag. Point out: nothing is stored until a human
   confirms.
2. **Consent gate.** As Dr Sara, "Access a patient record" → type the MediCard code → **Request
   access**. Switch to Ayesha → "Access requests" → **Approve**. Back as Dr Sara → pull to refresh
   → the grant appears → **Open**. The sensitive anxiety note is **not** in what the doctor sees.
3. **Advisory AI.** In the patient record, tap **AI summary**. The banner says advisory-only. The
   flags call out the rising HbA1c and the NSAID + ACE-inhibitor combination, each with a source
   chip that jumps to the record. Ask: *"Any documented penicillin allergy?"* → grounded answer
   with a source. Ask something off-record → it declines.
4. **Prescription assistant.** In the patient record, tap **Prescribe**. The allergy banner shows
   Penicillin. Tick **Metformin** and **Ramipril** from "Ayesha's record" — they drop into the
   draft, badged "from record". Add **Ibuprofen** manually → the checks panel flags the NSAID +
   ACE-inhibitor interaction against the ramipril she's already on; type **Amoxicillin** → an
   urgent allergy conflict. Remove those, **Save prescription** → it lands on Ayesha's timeline
   authored by Dr Sara. Point out: the assistant only ever lists medicines already in her record,
   the checks are a rule engine, and Dr Sara is the named prescriber.
6. **Access history.** As Ayesha → "Access history" → every view *and the prescription* Dr Sara
   made is listed, with the active grant and a **Revoke** button.
7. **Break-glass.** As Dr Sara → "Access a patient record" → **Emergency access (critical only)** →
   type a reason → you get allergies + current meds + conditions only, and it cannot open the full
   timeline. As Ayesha → "Access history" shows the emergency entry **with the stated reason**.
8. Close on **docs/STATUS.md** — what's solved, what isn't yet, and why the AI is deliberately
   advisory.
