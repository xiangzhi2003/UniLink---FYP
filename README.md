# UniLink

**UniLink** is a Final Year Project: a secure, cross-platform peer-to-peer campus
marketplace and rental application for university students. Students can buy, sell,
and rent academic items (textbooks, electronics, calculators, event equipment) within
a trusted, university-email-gated community.

**Primary SDG:** Goal 12 (Responsible Consumption & Production) — circular economy.

**Status: all planned sprints (1–4) complete.**

## Distinction features

1. **RAG AI Concierge** — semantic search (Pinecone + Gemini embeddings) blended with
   keyword search, a per-listing AI chatbot grounded in real listing data plus an
   admin-uploaded knowledge base, and AI-assisted listing creation from a photo/note.
2. **Escrow Vault** — funds held safely until handover is confirmed via the QR
   handshake; supports both Stripe Checkout and an in-app simulated wallet.
3. **QR Digital Handshake** — TOTP-based codes scanned at physical meetups to verify
   handover, covering both the pickup and (for rentals) the return leg.

## Tech stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) — single codebase for Android, iOS, and Web |
| Backend | Python + FastAPI, served by Uvicorn |
| Main database | Supabase (PostgreSQL, Auth, Storage, Realtime) |
| Vector database | Pinecone (separate namespaces for listings vs. admin knowledge docs) |
| AI models | Google Gemini — `gemini-embedding-001` (embeddings), `gemini-3.1-flash-lite` (chat/generation) |
| Payments | Stripe — **test mode only** — plus an in-app simulated wallet for escrow/late fees |
| QR security | TOTP via `pyotp` |
| Hosting | Railway (both the FastAPI backend and the Flutter web frontend) |
| Reverse proxy | Nginx (serves the built Flutter web app in its Railway container) |

## Feature overview

- **Auth** — `.edu.my`-gated registration/login, password reset, first-time profile completion.
- **Marketplace** — create/edit/delete listings (sale or rent, multi-photo), category
  filters, AI-assisted listing creation from a note/photos, favorites.
- **Semantic + keyword search** — the Browse search bar blends Pinecone semantic
  results with a plain keyword fallback so it never returns nothing outright.
- **Per-listing AI chatbot** — "Ask AI about this item," grounded in that listing's
  real data, the model's general knowledge, and any relevant admin-uploaded
  knowledge-base docs.
- **QR digital handshake** — TOTP codes for both the pickup and (for rentals) return legs.
- **Escrow** — pay via Stripe Checkout or wallet balance; funds release once handover
  is confirmed; refund path before pickup.
- **Wallet** — simulated balance/ledger, deposits/withdrawals via Stripe, and
  **late rental-return fees**: an overdue return charges the buyer's wallet (partial
  if insufficient) and credits the seller, tracking any shortfall as debt that blocks
  new rentals until settled.
- **Reviews & ratings** — buyers rate sellers after a completed deal; sellers can
  publicly reply to a review.
- **Messaging** — real-time chat via Supabase Realtime, with product-card sharing.
- **Reporting & moderation** — students can report a listing or user (preset reasons,
  no free text); admins review and resolve reports.
- **Admin panel** — a dedicated shell (`role = 'admin'` on the account) with a
  dashboard (marketplace-wide stats, category breakdown), listing moderation
  (view/remove, filters, read-only listing view), user management (suspend/unsuspend,
  search/sort), the reports queue, and RAG knowledge-base document management.
- **Transaction history & rental deadlines** — full deal history with status, and
  due-date tracking for active rentals.

## Project structure

```
marketplace_application/
├── CLAUDE.md                   # Root project context/conventions
├── README.md                   # This file
├── frontend/                   # Flutter app (Android, iOS, Web)
│   ├── CLAUDE.md                # Flutter-specific conventions
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/               # Supabase init, backend base URL, env config
│   │   ├── models/                # Listing, UserProfile, Transaction, Review, Report,
│   │   │                          # KnowledgeDoc, Wallet, Chat, Notification
│   │   ├── providers/             # Riverpod providers (auth, listings, reviews, wallet, etc.)
│   │   ├── screens/
│   │   │   ├── auth/               # welcome, login, register, forgot/reset password, suspended
│   │   │   ├── home/                # signed-in student shell (bottom nav)
│   │   │   ├── marketplace/         # browse, create/edit listing, listing detail, my listings
│   │   │   ├── profile/              # profile, seller profile, edit profile, review replies
│   │   │   ├── chat/                  # conversation list + detail
│   │   │   ├── transactions/           # deal list/detail, QR display/scan, pending purchase
│   │   │   ├── wallet/                  # balance, history, deposit/withdraw
│   │   │   ├── notifications/            # notification list
│   │   │   └── admin/                     # admin shell + dashboard/listings/users/reports/knowledge tabs
│   │   ├── services/               # One file per external concern — Supabase or the FastAPI backend
│   │   ├── theme/                   # AppTheme, AppColors, spacing/radius tokens
│   │   ├── utils/                    # Validators, error messages, recovery-flag storage
│   │   └── widgets/                   # Shared UI (AuthGate, buttons, cards, status chips, dialogs)
│   ├── android/ ios/ web/          # Platform packaging shells — no app logic here
│   ├── Dockerfile                  # Multi-stage build: compile web app, serve via nginx
│   ├── nginx.conf.template          # Nginx config (cache headers, dynamic $PORT)
│   └── pubspec.yaml
├── backend/                    # Python FastAPI
│   ├── CLAUDE.md                # Backend-specific conventions
│   ├── main.py                  # FastAPI entry (CORS, router registration, health check)
│   ├── routers/                  # search, escrow, qr, wallet, admin — HTTP only, delegates to services
│   ├── services/                  # auth, embedding_service, generation_service, escrow_service,
│   │                              # wallet_service, totp_service, notification_service, supabase_client
│   ├── models/                     # Pydantic request/response schemas, one file per domain
│   └── requirements.txt
```

## Running the project

### Frontend (from `frontend/`)

```
flutter pub get
flutter run -d chrome        # web
flutter run                  # connected mobile device/emulator
```

Copy `.env.example` to `.env` and fill in your own Supabase project's URL/anon key
and the deployed backend URL — `.env` is gitignored and never committed.

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
SUPABASE_KEY=...                    # service-role key, backend only
GEMINI_API_KEY=...
PINECONE_API_KEY=...
PINECONE_INDEX=unilink-listings
STRIPE_SECRET_KEY=sk_test_...       # test key only
WEB_APP_URL=...                     # deployed web frontend URL, used for Stripe Checkout redirects
```

## Database (Supabase)

Schema is managed manually via the Supabase SQL editor (no migrations folder) —
core tables: `profiles` (incl. `role`/`suspended`), `listings`, `transactions`
(incl. rental fields and `late_fee_owed`), `wallet_ledger`, `reviews` (incl. seller
replies), `reports`, `knowledge_docs`, plus Realtime-enabled `conversations`/`messages`
and `notifications`. Every table has Row Level Security enabled; admin-only tables
are accessed exclusively through the backend's service-role client, which bypasses RLS.

## Definition of "done" (MVP)

Campus-wall login • list + browse items • basic search • QR handshake •
escrow (test mode) • at least basic RAG search — **met**, plus the full distinction-tier
feature set above (reviews, wallet/late fees, admin panel, RAG knowledge base).
