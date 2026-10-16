# MediCard — hackathon MVP demo (static data, no server, no internet)

One flag, `DEMO=true`, makes the whole app run on a built-in story: a diabetic patient (**Ayesha
Khan**) and her doctor (**Dr Sara Ahmed**). No backend, no API keys, no Wi-Fi needed.

## Start it

```powershell
.\run_demo.ps1            # debug, opens Chrome on http://localhost:8080
.\run_demo.ps1 -Build     # release build, served on http://localhost:8080
```

Same thing by hand (the "env variable" is the `DEMO` flag; a compiled app has no `.env` file, so
Flutter reads it at build time):

```powershell
cd app
flutter run -d chrome --web-port 8080 --web-renderer html --dart-define-from-file=env/demo.json
```

`--web-renderer html` is deliberate: it uses the browser's own text engine, so nothing is
downloaded from Google and Urdu / emoji draw with the system fonts.

**Two screens at once:** open two browser tabs on `http://localhost:8080` — one as the **doctor**,
one as the **patient**. They share the demo story, so the patient's popup appears the moment the
doctor sends a request. Each tab keeps its own sign-in.

**One laptop:** the slim **DEMO** tab on the right edge of the screen → `Doctor / Patient / Reset`.

## The story (≈6 minutes)

| # | Who | Do this | They see |
|---|---|---|---|
| 1 | Patient | Home | One simple page: **ask bar** with a mic, **Next medicine** ("I took it"), today's care ring, **My numbers** (sugar 8.6 ↑ High · goal below 7), plain-language summary, latest reports (High / All normal) + **Load more**, small steps, **Emergency card** |
| 2 | Patient | Tap **"What does my sugar report mean?"** | The **AI health assistant** opens and *types* a perfect answer built from her own records. Chips offer the next questions. Try **"Can I take ibuprofen for my knee pain?"** — it refuses to advise and shows the facts |
| 3 | Patient | **Ask AI** button (bottom-left, on every tab) | Same assistant from anywhere |
| 4 | Patient | Today's care → **See plan** | Diet (eat more / less), walk, tests, follow-up |
| 5 | Patient | **Scan** → *Try with a sample lab report* (or any picture) | Scanner animation over the picture → review screen with the static values (2 flagged *please check*) → **Confirm** → *Verified* in her history |
| 6 | Doctor | Dashboard | Greeting, **AI brief**, stats, **Today's patients** (6, only Ayesha is live), **AI clinical assistant** chat, week chart, activity |
| 7 | Doctor | Type **`46A9 FT39`** in the top search box → **Search** | "Request sent" |
| 8 | Patient | (popup appears by itself) | "Dr Sara Ahmed wants to see your records" — 12 h, private items hidden, logged, revocable → **Yes, allow access** |
| 9 | Doctor | Dashboard updates itself → **Open** | One-page patient dashboard: profile, conditions, **lab-trend graphs**, timeline, results, **"Before you prescribe — from her history"** (penicillin allergy, ibuprofen reaction, metformin nausea, amlodipine stopped), AI insights, **chat about Ayesha** |
| 10 | Doctor | Tap the chat chips: *How has her HbA1c changed? · Any documented drug allergy? · Is it safe to continue ibuprofen?* | Typed answers with **source chips** ("Source · r11") that open the record |
| 11 | Doctor | **Prescribe** → *Use sample dictation* → *Write it for me* | Dictation becomes medicine lines + diet / walking / follow-up. Add **Ibuprofen** → history warning + NSAID/ACE check. **Amoxicillin** → urgent penicillin allergy |
| 12 | Doctor | **Save prescription** | Becomes the patient's care plan |
| 13 | Patient | Care plan / Sharing → *Access history* | New plan, the prescription in her records, everything Dr Sara opened, with local times. **Revoke** locks the doctor out |
| 14 | Doctor | **Emergency access** button → pick *Patient unconscious — cannot consent* → **Open emergency access** | (Use before step 7, or after **Revoke**.) A red **critical-only** screen: allergies first, current medicines, conditions — the full record stays closed. The patient's **Access history** then shows *Emergency access* **with the reason** |

Say out loud: *"AI output is advisory only — the licensed physician keeps full prescribing
authority. The patient controls who sees their history."*

## What is real vs static in demo mode

* **Real:** every screen and layout, the consent flow between two tabs, daily ticks, the scan →
  review → confirm flow, prescription saving, care-plan update, access log, the chat UI.
* **Static (on purpose):** all patient data, every AI answer (chat, summary, insights, brief),
  the scan result (any picture gives the same lipid-profile data), voice parsing, the OTP
  (`123456`), the doctor's schedule and weekly numbers.
* **Mic:** works in Chrome (fills the text box). If it does not, type, or use *Use sample dictation*.

## Accounts (all prefilled)

| Role | Sign in |
|---|---|
| Doctor | `sara.ahmed@medicard-demo.com`, password anything |
| Patient | `+92 300 1112222`, code `123456` |
| Ayesha's MediCard code | `46A9 FT39` |

## If something goes wrong on stage

* Page looks old → **Ctrl+Shift+R**, or Clear site data (Flutter caches the app).
* Story in a strange state → DEMO tab → **Reset**.
* Request seems stuck → the patient popup checks every 2 s; make sure the patient tab is open and
  on the same address as the doctor tab (`localhost:8080`, not `127.0.0.1`).

## Config files (`app/env/`)

| File | Use |
|---|---|
| `demo.json` | `DEMO=true` — static MVP demo |
| `local.json` | local FastAPI backend on `localhost:8010` |
| `live.json` | hosted backend `https://qamartech.org/api` |

## Checks that back this up

```powershell
cd app
flutter test                                                      # normal suite
flutter test test/demo_test.dart test/demo_ui_test.dart test/demo_smoke_test.dart --dart-define=DEMO=true
```

The smoke test opens **every** screen as patient and as doctor at phone (390 px) and desktop
(1440 px) width and fails on any exception or layout overflow.
