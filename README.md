# UniLink

**UniLink** is a Final Year Project: a secure, cross-platform peer-to-peer campus
marketplace and rental application for university students. Students can buy, sell,
and rent academic items (textbooks, electronics, calculators, event equipment) within
a trusted, university-email-gated community.

**Primary SDG:** Goal 12 (Responsible Consumption & Production) — circular economy.

## Distinction features (planned)

1. **RAG AI Concierge** — natural-language semantic search that understands intent,
   not just keywords.
2. **Escrow Vault** — funds held safely until handover is confirmed.
3. **QR Digital Handshake** — TOTP-based codes scanned at physical meetups to verify
   handover.

## Tech stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) — single codebase for Android, iOS, and Web |
| Backend | Python + FastAPI, served by Uvicorn |
| Main database | Supabase (PostgreSQL) |
| Vector database | Pinecone |
| AI framework | LangChain + an LLM embedding model |
| Payments | Stripe Connect — **test mode only** |
| QR security | TOTP via `pyotp` |
| Hosting | Railway (both the FastAPI backend and the Flutter web frontend) |
| Reverse proxy | Nginx (serves the built Flutter web app in its Railway container) |

## Project structure

```
marketplace_application/
├── CLAUDE.md                  # Root project context/conventions
├── README.md                  # This file
├── frontend/                  # Flutter app (Android, iOS, Web only)
│   ├── CLAUDE.md              # Flutter-specific conventions
│   ├── lib/                   # ALL app source code lives here
│   │   ├── main.dart          # App entry point
│   │   ├── config/            # Supabase init, env config
│   │   ├── models/            # Data classes (e.g. UserProfile)
│   │   ├── providers/         # Riverpod state providers (e.g. auth state)
│   │   ├── screens/
│   │   │   ├── auth/          # welcome, login, register, forgot/reset password
│   │   │   ├── home/          # home shell (placeholder, Sprint 2 target)
│   │   │   └── profile/       # edit profile
│   │   ├── services/          # External calls (Supabase auth, profile service)
│   │   ├── theme/             # App-wide colors, typography (AppTheme, AppColors)
│   │   ├── utils/             # Validators, error messages, recovery-flag storage
│   │   └── widgets/           # Shared UI (AuthGate, AuthHeaderScaffold, etc.)
│   ├── android/ ios/ web/     # Platform packaging shells — no app logic here
│   ├── Dockerfile             # Multi-stage build: compile web app, serve via nginx
│   ├── nginx.conf.template    # Nginx config (cache headers, dynamic $PORT)
│   └── pubspec.yaml           # Dependency manifest
├── backend/                   # Python FastAPI
│   ├── CLAUDE.md              # Backend-specific conventions
│   ├── main.py                # FastAPI entry (CORS, health check)
│   ├── routers/                # Planned: auth, listings, search, escrow, qr, messages
│   ├── services/                # Planned: rag_pipeline, stripe_service, totp_service
│   ├── models/                 # Planned: Pydantic schemas
│   └── requirements.txt
```

Note: `windows/`, `linux/`, and `macos/` platform folders were removed — this project
only targets Android, iOS, and Web.

## Current progress

**Sprint 1 — Foundation: done.**
- University-email-gated auth (`.edu.my` domains only) via Supabase, no separate email
  confirmation step.
- Two-step registration wizard, login, forgot/reset password (including cross-tab
  recovery handling).
- Campus-navy UI theme (`AppTheme`) shared across auth screens via `AuthHeaderScaffold`.
- Profile completion gate (`EditProfileScreen`) before entering the app.
- Placeholder home shell (`HomeShell`) with responsive nav scaffolding.
- FastAPI backend deployed on Railway with only a health-check route — auth talks
  directly to Supabase from Flutter, not through the backend yet.

**Sprint 2 — Marketplace: not started.** Next up: create listing (sale/rent),
browse grid, listing detail, categories/filters, keyword search, my-listings
management.

**Sprint 3 — Magic (QR handshake, escrow, RAG search, messaging): not started.**

**Sprint 4 — Polish (reviews, rental dashboard, admin panel): not started.**

## Running the project

### Frontend (from `frontend/`)

```
flutter pub get
flutter run -d chrome        # web
flutter run                  # connected mobile device/emulator
```

Copy `.env.example` to `.env` and fill in your own Supabase project's URL/anon key
before running — `.env` is gitignored and never committed.

### Backend (from `backend/`)

```
python -m venv venv
venv\Scripts\activate          # Windows (source venv/bin/activate on macOS/Linux)
pip install -r requirements.txt
uvicorn main:app --reload
```

## Deployment

Both the backend and the Flutter web frontend are deployed on Railway. The frontend
uses a multi-stage `Dockerfile`: one stage compiles the Flutter app to static
HTML/CSS/JS (`flutter build web --release`), the second stage serves that output
through a minimal nginx image configured via `nginx.conf.template` (handles Railway's
dynamic `$PORT` and sets cache-control headers so browsers don't serve stale cached
builds after a deploy). Local development never touches Docker — it's only used to
give Railway a reproducible way to build and serve the app in production.

## Environment variables (`backend/.env`)

```
SUPABASE_URL=...
SUPABASE_KEY=...
PINECONE_API_KEY=...
PINECONE_INDEX=unilink-listings
LLM_API_KEY=...
STRIPE_SECRET_KEY=sk_test_...      # test key only
STRIPE_PUBLISHABLE_KEY=pk_test_...  # test key only
```

## Definition of "done" (MVP)

Campus-wall login • list + browse items • basic search • QR handshake •
escrow (test mode) • at least basic RAG search. Everything beyond this pushes
toward distinction.
