# CLAUDE.md — Backend (Python + FastAPI)

> Backend-specific conventions. The root `../CLAUDE.md` has the full project context — read it first.

## What lives here
The Python FastAPI backend. It handles the "smart" work that shouldn't live in the
Flutter client: the RAG pipeline, Stripe escrow logic, and TOTP QR generation/verification.
Served by Uvicorn (with Nginx as reverse proxy in production only).

## Conventions

- **Structure:**
  - `main.py` — creates the FastAPI app, registers routers, sets up CORS.
  - `routers/` — one file per domain: `auth.py`, `listings.py`, `search.py`,
    `escrow.py`, `qr.py`, `messages.py`. Routers only handle HTTP; real work is
    delegated to services.
  - `services/` — business logic: `rag_pipeline.py`, `stripe_service.py`,
    `totp_service.py`. Keep external SDK calls here, not in routers.
  - `models/` — Pydantic schemas for request/response validation.
- **Secrets:** everything sensitive comes from `.env` via environment variables
  (use `python-dotenv` or Pydantic settings). `.env` is gitignored. Never hardcode.
- **CORS:** enable CORS for the Flutter web origin, or web calls will fail.
- **Async:** FastAPI endpoints that call the LLM or Stripe should be `async` — these
  are I/O-bound and shouldn't block other requests.
- **Return clean JSON.** Consistent shapes: `{"data": ...}` on success, clear error
  messages with proper HTTP status codes on failure.

## Feature notes

### QR Handshake (services/totp_service.py) — Sprint 3A
- Use `pyotp` to generate a time-based one-time code tied to a transaction.
- Endpoint to generate a code (seller side) and one to verify a scanned code
  (buyer side). On successful verify, mark the handover step complete.
- Codes must expire — that's the whole point (proves presence at that moment).

### Escrow (services/stripe_service.py) — Sprint 3B
- **TEST MODE ONLY.** Use `sk_test_...` keys.
- Flow: buyer pays → create a PaymentIntent with **manual capture** (money
  authorized but held) → on successful return-scan, **capture** it (release to
  seller) → if cancelled, **cancel/refund** the intent.
- Record every escrow state change in Supabase for the transaction history and
  for admin dispute handling.

### RAG Search (services/rag_pipeline.py) — Sprint 3C
- On listing create/update: build a text blob (title + description + category),
  embed it with a **cheap** embedding model, upsert to Pinecone with the listing
  ID as the vector ID. Store the listing itself in Supabase (source of truth).
- On search: embed the user's natural-language query, query Pinecone for nearest
  vectors, take the returned listing IDs, fetch full listings from Supabase, return them.
- **Cost control:** don't re-embed unchanged listings. Cache where sensible.
- Keep scope tight: this is item search, not a general chatbot.

## Key packages (requirements.txt)

```
fastapi
uvicorn[standard]
python-dotenv
supabase
pinecone-client
langchain
stripe
pyotp
qrcode
pydantic
```

## Run

```
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

## First task
Create `main.py` with CORS enabled and a single `GET /health` returning
`{"status": "ok"}`. Confirm it runs on `http://localhost:8000/health` before
anything else. The Flutter app will call this to prove the bridge works.
