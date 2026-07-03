# CLAUDE.md — UniLink Project Context

> This file gives Claude Code context about the project. Read it fully before working.

## Project Overview

**UniLink** is a Final Year Project: a secure, cross-platform peer-to-peer campus
marketplace and rental application for university students. Students can buy, sell,
and rent academic items (textbooks, electronics, calculators, event equipment)
within a trusted, university-email-gated community.

The three defining "distinction" features are:
1. **RAG AI Concierge** — natural-language semantic search (understands intent, not just keywords)
2. **Escrow Vault** — funds held safely until handover is confirmed
3. **QR Digital Handshake** — TOTP-based codes scanned at physical meetups to verify handover

**Primary SDG:** Goal 12 (Responsible Consumption & Production) — circular economy.

## Tech Stack (Locked — do not substitute without asking)

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) — single codebase for Android, iOS, and Web |
| Backend | Python + FastAPI, served by Uvicorn |
| Main database | Supabase (PostgreSQL) |
| Vector database | Pinecone |
| AI framework | LangChain + an LLM embedding model |
| Payments | Stripe Connect — **TEST MODE ONLY** |
| QR security | TOTP via `pyotp` |
| Hosting | Railway (both the FastAPI backend and the Flutter web frontend) |
| Reverse proxy | Nginx (serves the built Flutter web app in its Railway container) |
| IDE | VS Code |

## Repository Structure

```
unilink/
├── CLAUDE.md                 # This file (root context)
├── frontend/                 # Flutter app
│   ├── CLAUDE.md             # Flutter-specific conventions
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/           # env config, Supabase init, API base URL
│   │   ├── models/           # Listing, UserProfile, Transaction, Message
│   │   ├── screens/
│   │   │   ├── auth/         # login, register, verify_email
│   │   │   ├── marketplace/  # browse, listing_detail, create_listing
│   │   │   ├── rental/       # rental views + deadline tracking
│   │   │   ├── chat/         # messaging
│   │   │   ├── wallet/       # escrow, transaction_history
│   │   │   ├── qr/           # qr_display, qr_scan
│   │   │   └── profile/      # dashboard, edit_profile
│   │   ├── services/         # api_service, supabase_service, stripe_service
│   │   └── widgets/          # reusable UI components
│   └── pubspec.yaml
├── backend/                  # Python FastAPI
│   ├── CLAUDE.md             # Python-specific conventions
│   ├── main.py               # FastAPI entry
│   ├── routers/              # auth, listings, search, escrow, qr, messages
│   ├── services/             # rag_pipeline, stripe_service, totp_service
│   ├── models/               # Pydantic schemas
│   ├── requirements.txt
│   └── .env                  # secrets — NEVER commit (must be in .gitignore)
└── README.md
```

## Build Order (Sprints)

Work strictly in this order. Keep the app runnable at every stage.

- **Sprint 1 — Foundation:** Flutter + Supabase setup; university-email auth wall
  (only `.edu.my` domains allowed); email verification; navigation; user profiles.
- **Sprint 2 — Marketplace:** create listing (sale/rent toggle) with image upload;
  browse grid; listing detail; categories/filters; basic keyword search (temporary
  fallback before RAG); my-listings management.
- **Sprint 3 — Magic (in this order):**
  - 3A: QR handshake (TOTP generate + display + scan + verify)
  - 3B: Stripe escrow (test mode): pay → hold → release on return-scan → refund
  - 3C: RAG semantic search (embeddings → Pinecone → query → results)
  - 3D: In-app messaging (Supabase Realtime)
- **Sprint 4 — Polish:** reviews/ratings; rental deadline dashboard; transaction
  history; admin panel; RAG knowledge-base upload; responsive polish; bug fixes.

## User Roles

- **Student (Buyer/Renter and Seller/Owner — same account can be both):**
  register with verified `.edu.my` email, list items, search via RAG, message,
  pay via escrow, scan/show QR, track rentals, review, view history.
- **Admin:** manage users, moderate listings, handle reports/disputes, generate
  reports, update the RAG knowledge base.

## Core Rules & Conventions

1. **Skeleton first, organs later.** Always leave the project runnable. Build the
   simplest working version of a feature, confirm it runs, then enhance.
2. **One step at a time.** Don't build multiple sprint features in one go.
3. **No hardcoded secrets.** All keys live in `.env` (backend) or Flutter env
   config. `.env` must be gitignored. Tell the user what keys to add; never invent them.
4. **Stripe is TEST MODE only.** Use test cards (e.g. 4242 4242 4242 4242). Never
   attempt live mode — this is an academic project.
5. **Supabase is the source of truth.** Pinecone stores only the embedding vector
   plus the listing's ID — never duplicate full listing data into Pinecone.
6. **Explain as you go.** The developer must understand the code to defend it in a
   viva. Keep explanations concise and practical.
7. **Cost awareness.** LLM embedding calls cost money. Use a cheap embedding model,
   and don't re-embed a listing that hasn't changed.
8. **Commit after each working milestone** with clear messages.

## Environment Variables (put in backend/.env)

```
SUPABASE_URL=...
SUPABASE_KEY=...
PINECONE_API_KEY=...
PINECONE_INDEX=unilink-listings
LLM_API_KEY=...
STRIPE_SECRET_KEY=sk_test_...      # TEST key only
STRIPE_PUBLISHABLE_KEY=pk_test_...  # TEST key only
```

## Run Commands

Frontend (from `frontend/`):
```
flutter pub get
flutter run -d chrome        # web
flutter run                  # connected mobile device
```

Backend (from `backend/`):
```
python -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

## Definition of "Done" (MVP for passing)

Campus-wall login • list + browse items • basic search • QR handshake •
escrow (test mode) • at least basic RAG search. Everything beyond this pushes
toward distinction.
