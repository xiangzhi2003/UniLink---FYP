# UniLink — Final Year Project Documentation

This document is a complete reference for **UniLink**, written so it can be pasted
into a fresh conversation to help draft the FYP report/documentation. It covers the
problem, roles, every feature actually built (organized by sprint), the tech stack
and why each choice was made, system architecture, database schema, API surface,
key design decisions, known limitations, how features were tested/verified, and —
in Sections 11–13 — the structured data needed to actually **draw diagrams**: a
full use-case list per actor, class/entity definitions with exact attributes for a
class diagram, and step-by-step flows for sequence diagrams of the three core
mechanics (QR handshake, escrow payment, rental reminder).

---

## 1. Project Overview

**UniLink** is a secure, cross-platform peer-to-peer campus marketplace and rental
application for university students. Students can buy, sell, and rent academic
items — textbooks, electronics, calculators, event equipment — within a trusted,
university-email-gated community (only `.edu.my` addresses can register).

**Primary SDG alignment:** Goal 12 — Responsible Consumption & Production. The core
idea is a circular economy for campus items: instead of items going unused or being
thrown away after a semester, students resell or rent them to each other.

**Project status:** all four planned sprints are complete, plus two additional
AI-driven features added after supervisor feedback (Section 4).

### Problem being solved

University students frequently buy items (textbooks, calculators, electronics) they
only need for a single semester or a short period, then either let them sit unused
or dispose of them. Existing general marketplace apps (Facebook Marketplace,
Carousell, etc.) aren't scoped to a trusted campus community, have no built-in
verification that a real handover happened, and have no safe way to hold payment
until an item changes hands. UniLink solves this by combining:
- A closed, university-verified community (reduces stranger-danger risk of P2P trading)
- Escrow (payment isn't released until both sides confirm handover)
- A cryptographic handshake (QR + TOTP) proving the handover physically happened
- AI-assisted search/discovery so listings are easy to find by natural language, not just exact keywords

### Target users / roles

- **Student (Buyer/Renter and Seller/Owner — same account can be both roles):**
  registers with a verified `.edu.my` email, lists items for sale or rent, searches
  via semantic + keyword search, messages other students, pays via escrow, shows/
  scans QR codes at handover, tracks active rentals, leaves reviews, views their
  transaction history and AI-generated performance report.
- **Admin:** a separate role (`profiles.role = 'admin'`) with a dedicated admin
  panel — manages users (suspend/unsuspend), moderates listings (remove), handles
  user-filed reports/disputes, views marketplace-wide stats, and manages the RAG
  chatbot's knowledge base documents.

---

## 2. Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Frontend | Flutter (Dart) | Single codebase targets Android, iOS, and Web from one project |
| Backend | Python + FastAPI (Uvicorn) | Handles logic that shouldn't live client-side: escrow, TOTP, AI calls, scheduled jobs |
| Main database | Supabase (PostgreSQL, Auth, Storage, Realtime) | Source of truth for all structured data; built-in RLS, auth, and realtime subscriptions used directly for chat |
| Vector database | Pinecone | Semantic search over listing embeddings + a separate namespace for the AI chatbot's knowledge base |
| AI models | Google Gemini — `gemini-embedding-001` (embeddings), `gemini-3.1-flash-lite` (chat/generation) | Cheap-tier models chosen deliberately to control per-call cost |
| Payments | Stripe (test mode only) + an in-app simulated wallet | Stripe Checkout with manual-capture PaymentIntents implements the escrow hold/release/refund cycle; the wallet is a simpler always-available alternative payment rail used for the same escrow logic |
| QR / handshake security | TOTP via `pyotp` | Time-based one-time codes prove physical presence at the moment of handover, not just a static QR anyone could screenshot and reuse |
| Email | Gmail SMTP (`smtplib`, stdlib) | No new dependency; sends the rental due-date reminder |
| Scheduling | APScheduler (`AsyncIOScheduler`) | Runs the daily rental-reminder check inside the FastAPI process |
| Hosting | Railway | Both the FastAPI backend and the Flutter web build are deployed here |
| Reverse proxy | Nginx | Serves the compiled Flutter web app inside its Railway container |

---

## 3. Features Built, by Sprint

### Sprint 1 — Foundation
- Flutter + Supabase project setup
- University-email auth wall: only `.edu.my` domains accepted at registration
- Login / register / forgot-password / reset-password flows
- First-time profile completion (name, university, etc.)
- Signed-in home shell with bottom navigation

### Sprint 2 — Marketplace
- Create/edit/delete listings — sale or rent toggle, multi-photo upload
- Browse grid with category filters
- Listing detail screen
- Basic keyword search (temporary fallback before semantic search was built)
- My-listings management (a seller's own active/sold/removed listings)
- Favorites (save listings for later)

### Sprint 3 — "Magic" (the three distinction features)

**3A — QR Digital Handshake**
- TOTP (`pyotp`) codes generated per transaction, rotating on a short interval
- Seller shows a code at pickup; buyer scans (or types) it to confirm handover
- For rentals, the same mechanism runs a *second* time on return: buyer shows a
  return code, seller scans it — this closes out the rental and (if overdue)
  triggers the late-fee charge
- Codes expire, so a screenshot of an old code can't be reused later

**3B — Stripe Escrow (test mode)**
- Buyer pays via Stripe Checkout with `capture_method: manual` — money is
  *authorized and held*, not actually taken yet
- On successful pickup-scan, the PaymentIntent is **captured** (released to the
  platform, credited to the seller's wallet)
- If a deal is cancelled before pickup, the PaymentIntent is **cancelled**
  (Stripe-funded) or the debited amount is refunded back to the wallet
  (wallet-funded)
- A parallel **in-app simulated wallet** payment path exists too — buyer pays
  straight from their wallet balance, no Stripe redirect, useful for demoing
  without needing test card numbers every time

**3C — RAG Semantic Search**
- On listing create/update: a text blob (title + description + category) is
  embedded with `gemini-embedding-001` and upserted into Pinecone, keyed by the
  listing's ID (Pinecone stores only the vector + ID — Supabase remains the
  single source of truth for the actual listing data)
- On search: the user's natural-language query is embedded and matched against
  Pinecone; results are blended with a plain keyword fallback so a search never
  returns nothing outright
- A **per-listing AI chatbot** ("Ask AI about this item") answers questions
  grounded in that specific listing's real data, plus any relevant admin-uploaded
  knowledge-base document, plus the model's general knowledge
- **AI-assisted listing creation**: seller provides a rough note and/or up to 3
  photos, and the AI suggests a title/description/category/price
- Cost control: unchanged listings are never re-embedded

**3D — In-app Messaging**
- Real-time chat via Supabase Realtime (no polling)
- Product-card sharing inside a conversation (share a listing directly in chat)

### Sprint 4 — Polish
- **Reviews & ratings**: buyers rate sellers after a completed deal; sellers can
  publicly reply to a review
- **Rental deadline tracking**: `rental_due_date` stored and surfaced on the
  transaction detail screen
- **Transaction history**: full deal list with status (pending/active/completed/
  cancelled), filterable
- **Admin panel**: dashboard (marketplace-wide stats + category breakdown),
  listing moderation (view/remove with filters), user management
  (suspend/unsuspend, search/sort), a reports queue (user-filed listing/user
  reports with preset reasons, no free text), and RAG knowledge-base document
  management (create/delete docs that feed the per-listing chatbot)
- Responsive layout tuned for both mobile and wide web browsers
- Various bug fixes throughout

---

## 4. Post-Sprint-4 Additions (Supervisor-Requested)

After Sprint 4, the supervisor reviewed the app and requested two further
distinction-level features, built and fully verified in a later phase of
development:

### 4A — Rental Return Reminder (email + in-app notification)

**Design:** on the exact day a rental is due back (not after, to avoid nagging),
a scheduled backend job automatically sends the buyer both an in-app notification
and an email, reminding them to return the item and warning that a daily late fee
applies from the day it becomes overdue.

- Runs once daily via `AsyncIOScheduler`, scheduled for **9:00 AM Malaysia time**
  (explicit `Asia/Kuala_Lumpur` timezone, not the server's UTC default)
- Queries `transactions` for `type = 'rent'`, `status = 'active'`,
  `rental_due_date = today`
- A `last_overdue_notified_at` column guards against double-sending if the
  process restarts mid-day
- Email sent via **Gmail SMTP** (`smtplib`, no external API/paid service) —
  reads `GMAIL_ADDRESS` / `GMAIL_APP_PASSWORD` from environment variables, never
  hardcoded
- The reminder is a **one-time nudge on the due date only** — deliberately does
  *not* keep re-notifying after the deadline passes (the existing return-scan
  late-fee logic still handles the actual financial penalty independently)

**Verification performed:**
- In-app notification: confirmed delivered and displaying correctly
- Email send: confirmed working via `smtplib` (zero exceptions) and confirmed
  *actual delivery* to two independent external test addresses
- **Known, documented limitation**: delivery specifically to the university's
  own `.edu.my` Microsoft 365 mailboxes is silently blocked by APU's
  institutional Exchange Online Protection (EOP) spam quarantine — confirmed via
  a systematic elimination process (checked spam/junk folder, checked for a
  bounce-back to the sender, ruled out email case-sensitivity, confirmed
  delivery works to non-institutional addresses). This is an external
  university IT policy, not a defect in the application — the code, credentials,
  and email content were all independently verified correct.

### 4B — AI Sales/Rental Report ("Seller Report")

**Design principle — "math decides the facts, AI only narrates them"**: every
number shown (deal counts, earnings, category breakdown, trend) is computed
deterministically from real `transactions` rows via plain Python/Supabase
queries. Gemini is only used to turn those already-correct numbers into a short,
readable narrative, explicitly instructed never to invent or estimate anything
beyond what it's given. This mirrors the same philosophy already used for the
late-fee/debt-settlement math elsewhere in the app.

- **Access:** Wallet tab → "View Sales Report"
- **Month / Year toggle**
- **Stat cards:** deals completed (sale vs. rent split), total earnings with
  percentage change vs. the previous equivalent period
- **Earnings Trend line chart**: daily points for the month view (up to today),
  monthly points for the year view (up to the current month) — custom-painted
  in Flutter, no external charting library
- **Earnings by Category bar chart**: per-category earnings, highest first
- **AI Insights card**: a 4–7 sentence Gemini-written narrative covering the
  period's performance, comparison to the previous period, which category
  earned the most and why, the best-earning specific item by name, and one
  concrete suggestion — all strictly grounded in the computed numbers above
- **Edge case handling**: if there's no activity at all this period, or if this
  is the seller's very first period with any completed deals (no prior period
  to compare against), the prompt branches into a distinct, honest message
  instead of fabricating a "growth" or "decline" comparison against nonexistent
  data — this was a real bug caught and fixed during testing (the first version
  incorrectly claimed "growth" for a seller's very first month)

**Backend endpoint:** `GET /reports/seller-summary?period=month|year`, scoped to
the logged-in user (`current_user_id`) — a seller only ever sees their own report.

---

## 5. System Architecture

```
┌─────────────────┐         ┌──────────────────────┐
│  Flutter App      │◄──────►│  Supabase             │
│  (mobile + web)    │        │  - PostgreSQL (data)   │
│                     │        │  - Auth (.edu.my gate)  │
│                     │        │  - Storage (photos)      │
│                     │        │  - Realtime (chat)         │
└─────────┬───────────┘        └──────────────────────────┘
          │ HTTP (Bearer token = Supabase access token)
          ▼
┌───────────────────────────────────────────────────────┐
│  FastAPI Backend (Railway)                               │
│  routers/  → escrow, qr, search, wallet, admin, reports   │
│  services/ → business logic + external SDK calls            │
│  - AsyncIOScheduler: daily 9am MYT rental reminder job        │
└───────┬─────────────┬─────────────┬─────────────┬───────────┘
        │              │             │              │
        ▼              ▼             ▼              ▼
   ┌─────────┐   ┌───────────┐  ┌─────────┐   ┌──────────────┐
   │ Stripe    │   │ Pinecone   │  │ Gemini   │   │ Gmail SMTP     │
   │ (escrow)   │   │ (vectors)  │  │ (AI)      │   │ (reminders)    │
   └─────────┘   └───────────┘  └─────────┘   └──────────────┘
```

**Key architectural decisions:**
- Auth (Sprint 1) talks **directly** from Flutter to Supabase — no backend
  round-trip needed for login/register, since Supabase Auth already handles
  that securely.
- Anything requiring a secret key (Stripe, Gemini, Pinecone, Gmail) or
  server-side business logic (escrow state machine, TOTP verification, RLS
  bypass for admin actions) goes through the FastAPI backend — the Flutter
  client never holds any of those keys.
- Supabase is the single source of truth for all structured data. Pinecone
  stores **only** the embedding vector plus the listing's ID — never a copy of
  the listing content itself, to avoid two systems disagreeing about what a
  listing actually says.
- Every table has Row Level Security enabled. Admin-only operations go through
  the backend's **service-role** Supabase client, which deliberately bypasses
  RLS — this is why admin actions must always be server-side, never a direct
  client call.

---

## 6. Database Schema (Supabase, PostgreSQL)

Managed manually via the Supabase SQL editor (no migration framework). Core tables:

| Table | Purpose |
|-------|---------|
| `profiles` | User profile, incl. `role` (student/admin), `suspended` flag, `email`, `full_name`, `university` |
| `listings` | Marketplace items — title, description, category, price, sale/rent type, photos, owner |
| `transactions` | Every deal — buyer/seller/listing IDs, `type` (sale/rent), `status`, `escrow_status`, Stripe IDs, `amount`, rental fields (`rental_days`, `rental_start_date`, `rental_due_date`, `late_fee_owed`, `last_overdue_notified_at`) |
| `wallet_ledger` | Paired debit/credit entries for every wallet-affecting event (payments, captures, refunds, late fees, deposits, withdrawals) — always inserted as matched pairs tagged with the same `transaction_id` |
| `reviews` | Buyer ratings/comments after a completed deal, plus seller replies |
| `reports` | User-filed moderation reports against a listing or user (preset reasons) |
| `knowledge_docs` | Admin-authored reference documents that feed the per-listing AI chatbot's retrieval |
| `conversations` / `messages` | Realtime-enabled chat |
| `notifications` | In-app notifications (payment events, QR handshake events, rental reminders, late fees, etc.) |

---

## 7. Backend API Surface

```
GET  /health                          liveness check

POST /qr/current                      get the current TOTP code to display
POST /qr/verify                       verify a scanned/typed code, advance handshake

POST /escrow/start                    begin Stripe Checkout for a not-yet-created deal
POST /escrow/confirm-and-create       create the transaction once payment is confirmed held
POST /escrow/pay-with-wallet          pay straight from wallet balance, no Stripe redirect
POST /escrow/create                   begin Stripe Checkout for an existing transaction
POST /escrow/confirm                  sync escrow status after returning from Checkout
POST /escrow/refund                   cancel deal + release hold (before pickup only)

POST /search/query                    semantic search — returns matching listing IDs
POST /search/embed-listing            index a listing for search (on create/update)
POST /search/delete-listing           remove a listing's vector (on delete)
POST /search/listing-chat             per-listing AI chatbot Q&A
POST /search/suggest-listing          AI-assisted listing creation from note/photos

GET  /wallet/summary                  balance + ledger history
POST /wallet/deposit/start            begin a Stripe top-up
POST /wallet/deposit/confirm          confirm a completed top-up
POST /wallet/withdraw/start           begin a withdrawal
POST /wallet/withdraw/confirm         confirm a completed withdrawal
POST /wallet/settle-debt              pay off outstanding late-fee debt

GET  /reports/seller-summary          AI-narrated seller performance report

GET  /admin/stats                     marketplace-wide counts (dashboard)
GET  /admin/listings                  every listing (moderation view)
POST /admin/listings/remove           remove a listing + its search vector
GET  /admin/users                     all users
POST /admin/users/set-suspended       suspend/unsuspend a user
GET  /admin/reports                   all user-filed reports
POST /admin/reports/resolve           mark a report resolved
GET  /admin/knowledge                 list knowledge-base docs
POST /admin/knowledge                 create a knowledge-base doc
POST /admin/knowledge/delete          delete a knowledge-base doc
```

All routes except `/health` require a valid Supabase-issued Bearer token; admin
routes additionally require `profiles.role = 'admin'` for that user.

---

## 8. Key Design Decisions & Rationale

- **Manual-capture Stripe PaymentIntents implement escrow** without needing
  Stripe Connect's full marketplace payout infrastructure — appropriate for an
  academic test-mode project while still demonstrating a real hold/release/
  refund cycle.
- **TOTP over a static QR code** specifically because a static code could be
  screenshotted and reused later; a rotating time-based code proves the parties
  were physically present *at that moment*.
- **"AI narrates, math decides the facts"** is a deliberate, repeated pattern
  across the app (late-fee calculation, the seller AI report) — the LLM is
  never trusted to compute or invent a number that affects money or a factual
  claim; it only writes prose describing numbers a plain function already
  computed correctly. This bounds the AI's blast radius and avoids
  hallucinated financial figures.
- **Pinecone stores only vectors + IDs**, never full listing content, so
  there's exactly one source of truth (Supabase) and no risk of the two
  systems drifting out of sync.
- **Cheap-tier Gemini models** (`gemini-3.1-flash-lite`, `gemini-embedding-001`)
  chosen deliberately, and embeddings are skipped for unchanged listings — a
  conscious cost-control decision given this is a self-funded student project.
- **Gmail SMTP over a transactional email API** was chosen after discovering
  that a free-tier email API's shared sending domain can only deliver to the
  account owner's own address without a verified custom domain — Gmail SMTP
  with an app password can send to any recipient with zero domain setup,
  appropriate for a no-budget student project.
- **No admin "test button" for the rental reminder** — deliberately kept out of
  the shipped app; the feature is fully automatic by design, and was tested by
  triggering the real underlying function directly during development, not by
  adding a manual-trigger affordance to the production UI.

---

## 9. Known Limitations

- **Stripe is test-mode only** — by design, this is an academic project, not a
  real payment processor integration.
- **Email delivery to APU's own `.edu.my` addresses is blocked by the
  university's Microsoft 365 spam quarantine policy** — verified as an
  institutional filtering issue, not an application defect (see Section 4A).
  Fixing this would require APU's IT department whitelisting the sender, which
  is outside the application's control.
- **Wallet balance is simulated**, not a real financial ledger connected to a
  bank — appropriate for a prototype demonstrating the escrow/payment flow.
- **No push notifications** — in-app notifications are pull-based (fetched when
  the app is open), not delivered via FCM/APNs.

---

## 10. Suggested Report Structure (for drafting)

1. **Introduction** — problem statement, SDG alignment, objectives
2. **Literature Review** — existing marketplace apps, gaps this project addresses
3. **System Design** — architecture diagram (Section 5), database schema (Section 6), use-case/role breakdown (Section 1)
4. **Implementation** — walk through each sprint's features (Section 3), then the two post-sprint AI features (Section 4) as the "distinction" showcase
5. **Testing & Verification** — the systematic debugging process used for the rental reminder email (spam check → bounce-back check → control-group test → root-cause conclusion) is a strong, concrete example of methodical testing worth writing up in detail
6. **Discussion / Limitations** — Section 9, framed honestly as scoped/documented constraints rather than unfinished work
7. **Conclusion & Future Work** — e.g. custom domain email for guaranteed .edu.my delivery, real payment integration, push notifications

---

## 11. Use Cases (for a Use Case Diagram)

Two actors: **Student** (every registered user — the same account can act as
buyer/renter and as seller/owner) and **Admin** (a `profiles.role = 'admin'`
account). Admin does not inherit Student use cases in this system — an admin
account browses/moderates but the app doesn't treat "admin" as a superset role
for the marketplace-participant use cases below; treat them as two separate
actors on the diagram unless your convention prefers an inheritance arrow from
Admin to Student.

### Actor: Student

**Account**
- Register (with `.edu.my` email verification)
- Log in / Log out
- Reset password
- Complete/edit profile

**Marketplace**
- Create listing (sale or rent, multi-photo, optionally AI-assisted from a note/photo)
- Edit listing
- Delete listing
- Browse listings (with category filters)
- Search listings (semantic + keyword)
- View listing detail
- Ask AI about a listing (per-listing chatbot)
- Add/remove favorite
- View "my listings"

**Transacting**
- Buy a listing (sale)
- Rent a listing (choose rental duration)
- Pay via Stripe Checkout
- Pay via wallet balance
- Cancel a deal before pickup (triggers refund)
- Show QR/TOTP code (as the pickup giver, or return giver for a rental)
- Scan/verify QR/TOTP code (as the pickup receiver, or return receiver for a rental)
- Extend... *(removed feature — do not include; rental extension was built then
  explicitly removed per product decision, see git history if you need the
  before/after story for a design-decisions section)*
- View transaction history
- View transaction detail (including live escrow/rental status)

**Post-transaction**
- Leave a review + rating for a seller
- Reply to a review received (as the seller)
- Receive rental due-today reminder (notification + email) — system-initiated,
  but worth including as a use case triggered by "Time passes" (an external
  time-based actor/trigger)
- Settle outstanding late-fee debt

**Wallet**
- View wallet balance/history
- Deposit funds (via Stripe)
- Withdraw funds (via Stripe)
- View AI Sales Report (month/year toggle, stat cards, trend chart, category chart, AI narrative)

**Communication**
- Message another user
- Share a listing in a chat

**Moderation (as a reporting party)**
- Report a listing
- Report a user

### Actor: Admin

- Log in (same login use case, but the account has `role = 'admin'`)
- View dashboard (marketplace-wide stats, category breakdown)
- View all listings (moderation view)
- Remove a listing
- View all users
- Suspend / unsuspend a user
- View all reports
- Resolve a report
- View knowledge-base documents
- Create a knowledge-base document
- Delete a knowledge-base document

### External/system triggers (optional to model as actors)

- **Scheduler (time-based)** → triggers the daily rental due-today reminder job
- **Stripe** → webhook-less in this design (the app polls/confirms on return
  from Checkout rather than listening for webhooks) — if your diagram wants an
  external system actor, Stripe is invoked by the Student's "Pay" use case, not
  the other way around
- **Gemini** → invoked by "Search listings", "Ask AI about a listing",
  "Create listing (AI-assisted)", and "View AI Sales Report"
- **Pinecone** → invoked by "Search listings", "Create listing", "Edit listing", "Delete listing"

---

## 12. Class / Entity Definitions (for a Class Diagram or ER Diagram)

These are the real Dart model classes from `frontend/lib/models/`, which mirror
the Supabase tables. Field types are as declared in Dart; nullable fields are
marked `?`. Use these as your class attributes — they're taken directly from
the actual codebase, not reconstructed from memory.

### UserProfile (`profiles` table)
```
UserProfile
- id: String (PK)
- email: String
- fullName: String?
- university: String?
- role: String            // "student" | "admin"
- suspended: bool
```

### Listing (`listings` table)
```
Listing
- id: String? (PK)
- sellerId: String (FK -> UserProfile.id)
- title: String
- description: String
- price: double
- category: String
- condition: String
- listingType: String     // "sale" | "rent"
- status: String
- imageUrls: List<String>
- createdAt: DateTime?
- sellerName: String?     // denormalized, joined for display
- tags: List<String>
- location: String?
```

### TransactionDeal (`transactions` table)
```
TransactionDeal
- id: String (PK)
- listingId: String (FK -> Listing.id)
- buyerId: String (FK -> UserProfile.id)
- sellerId: String (FK -> UserProfile.id)
- type: String                  // "sale" | "rent"
- status: String                 // "pending" | "active" | "completed" | "cancelled"
- pickupScannedAt: DateTime?
- returnScannedAt: DateTime?
- escrowStatus: String            // "pending" | "held" | "captured" | "refunded"
- checkoutSessionId: String?
- createdAt: DateTime
- amount: double?                 // RM actually charged, snapshotted at confirmation
- rentalDays: int?
- rentalStartDate: DateTime?
- rentalDueDate: DateTime?
- listingTitle: String?           // denormalized, joined for display
- listingPrice: double?
- listingImages: List<String>
- buyerName: String?
- sellerName: String?

// Backend-only columns not surfaced in the Flutter model, but present in the
// database and used server-side:
- late_fee_owed: numeric          // tracked debt if a late fee couldn't be fully charged
- last_overdue_notified_at: date  // guards the daily reminder job against double-sending
```

### WalletEntry / WalletSummary (`wallet_ledger` table)
```
WalletEntry
- id: String (PK)
- transactionId: String? (FK -> TransactionDeal.id)
- amount: double            // positive = credit, negative = debit
- type: String              // see full list of ledger types below
- createdAt: DateTime
- listingTitle: String?
- dealType: String?

WalletSummary
- balance: double            // derived: sum of all WalletEntry.amount for the user
- history: List<WalletEntry>
- outstandingDebt: double
```

**All `wallet_ledger.type` values actually used in the backend** (useful for a
state/ledger diagram, or just to document the enum):
`wallet_payment`, `credit`, `late_fee_charge`, `late_fee_credit`,
`debt_settlement_charge`, `debt_settlement_credit`, `withdrawal`, `deposit`,
`refund`

Every wallet-affecting event is inserted as a **matched debit/credit pair**
sharing the same `transaction_id` — e.g. a late fee inserts one row on the
buyer (`late_fee_charge`, negative) and one on the seller
(`late_fee_credit`, positive), in the same operation.

### Review (`reviews` table)
```
Review
- id: String (PK)
- transactionId: String (FK -> TransactionDeal.id)
- listingId: String (FK -> Listing.id)
- reviewerId: String (FK -> UserProfile.id)
- sellerId: String (FK -> UserProfile.id)
- rating: int                // 1-5
- comment: String?
- createdAt: DateTime
- sellerReply: String?
- sellerReplyAt: DateTime?
- reviewerName: String?
```

### Report (`reports` table)
```
Report
- id: String (PK)
- reason: String
- status: String              // "open" | "resolved"
- createdAt: DateTime
- reporterName: String?
- listingId: String? (FK -> Listing.id)     // set when a listing was reported
- listingTitle: String?
- reportedUserId: String? (FK -> UserProfile.id)  // set when a user was reported
- reportedUserName: String?
```

### Conversation / Message (`conversations` / `messages` tables)
```
Conversation
- id: String (PK)
- listingId: String? (FK -> Listing.id)
- buyerId: String (FK -> UserProfile.id)
- sellerId: String (FK -> UserProfile.id)
- listingTitle: String?
- buyerName: String?
- sellerName: String?
- lastMessage: String?
- lastMessageAt: DateTime?
- unreadCount: int
- recentListingTitle: String?

Message
- id: String (PK)
- conversationId: String (FK -> Conversation.id)
- senderId: String (FK -> UserProfile.id)
- content: String
- isRead: bool
- createdAt: DateTime
- isDeleted: bool
- imageUrl: String?
- listingId: String?           // set when a listing card is shared in-chat
```

### AppNotification (`notifications` table)
```
AppNotification
- id: String (PK)
- type: String              // see full list below
- title: String
- body: String
- transactionId: String? (FK -> TransactionDeal.id)
- readAt: DateTime?
- createdAt: DateTime
```

**All `notification.type` values actually used in the backend:**
`payment_received`, `payment_successful`, `payment_released`, `deal_completed`,
`late_fee_charged`, `refund_processed`, `deal_cancelled`, `rental_due_today`

### KnowledgeDoc (`knowledge_docs` table)
```
KnowledgeDoc
- id: String (PK)
- title: String
- body: String
- createdAt: DateTime
```

### Entity relationship summary (for an ER diagram)

```
UserProfile 1───* Listing            (a seller owns many listings)
UserProfile 1───* TransactionDeal    (as buyer, via buyerId)
UserProfile 1───* TransactionDeal    (as seller, via sellerId)
Listing     1───* TransactionDeal
TransactionDeal 1───* WalletEntry    (one deal can generate multiple ledger rows: payment, late fee, refund, etc.)
TransactionDeal 1───0..1 Review
TransactionDeal 1───* AppNotification
UserProfile 1───* WalletEntry
UserProfile 1───* Review              (as reviewer)
UserProfile 1───* Review              (as seller, via sellerId)
UserProfile 1───* Report              (as reporter)
UserProfile 1───* Report              (as reported user, optional)
Listing     1───0..1 Report           (optional — a report targets either a listing or a user)
UserProfile 1───* Conversation        (as buyer)
UserProfile 1───* Conversation        (as seller)
Conversation 1───* Message
UserProfile 1───* Message             (as sender)
Listing     1───0..1 Conversation     (a conversation is usually tied to the listing it started from)
```

---

## 13. Sequence Diagrams — Core Flows

Written as step lists; translate directly into UML sequence diagram lifelines
(Student, Flutter App, FastAPI Backend, Supabase, Stripe/Gemini/Pinecone/Gmail
as needed).

### 13.1 QR Digital Handshake (pickup leg, sale)

1. Buyer pays for a listing (see 13.2) → transaction created, `escrow_status = held`
2. Seller opens the transaction detail screen, taps "Show QR"
3. Flutter App → Backend: `POST /qr/current` (as the giver)
4. Backend → generates a TOTP code via `pyotp`, tied to the transaction ID
5. Backend → Flutter App: returns QR payload (transaction ID + current code) + seconds until it expires
6. Seller's screen renders the QR code
7. Buyer scans the QR (or types the code) on their device
8. Flutter App → Backend: `POST /qr/verify` (as the receiver) with transaction ID + code
9. Backend verifies the TOTP code is valid and not expired
10. Backend updates `transactions.pickup_scanned_at`, sets `status = 'completed'` (sale) or `'active'` (rent)
11. Backend → `escrow_service.capture()`: captures the Stripe PaymentIntent (or, for wallet payments, credits the seller's wallet)
12. Backend creates notifications for both parties ("Payment released" / "Deal completed")
13. Backend → Flutter App: success response
14. Flutter App updates the UI to reflect the completed/active state

### 13.2 Escrow Payment (Stripe Checkout path)

1. Buyer taps "Buy" / "Rent" on a listing detail screen
2. Flutter App → Backend: `POST /escrow/start` (listing ID, seller ID, type, rental days if renting)
3. Backend checks: buyer isn't the seller; if renting, buyer has no outstanding late-fee debt
4. Backend → Stripe: creates a Checkout Session with `capture_method: manual`
5. Stripe → Backend: session ID + hosted Checkout URL
6. Backend → Flutter App: returns the Checkout URL
7. Flutter App opens the Stripe-hosted Checkout page (buyer enters test card details)
8. Buyer completes payment on Stripe's page → Stripe redirects back to the app
9. Flutter App → Backend: `POST /escrow/confirm-and-create` (session ID, listing/seller/type)
10. Backend → Stripe: retrieves the session, checks the PaymentIntent status is `requires_capture` (= authorized and held)
11. Backend creates the `transactions` row (`escrow_status = 'held'`) — this is the **first** point the transaction exists in the database
12. Backend creates notifications for both parties ("Payment received" / "Payment successful")
13. Backend → Flutter App: transaction ID + `escrow_status = 'held'`
14. (Later) the QR handshake pickup leg (13.1) captures the held payment

### 13.3 Rental Due-Today Reminder (automatic, scheduled)

1. `AsyncIOScheduler` (running inside the FastAPI process) fires at 09:00 Asia/Kuala_Lumpur, every day
2. Scheduler calls `rental_reminder_service.check_due_today_rentals()` directly (no HTTP involved — this is an internal cron job, not an API call)
3. Function → Supabase: queries `transactions` where `type = 'rent'`, `status = 'active'`, `rental_due_date = today`
4. For each matching row not already notified today (`last_overdue_notified_at != today`):
   a. Function → Supabase: creates an `AppNotification` (`type = 'rental_due_today'`) for the buyer
   b. Function → Gmail SMTP: sends a reminder email to the buyer's `profiles.email`, with the listing title and the daily late-fee rate
   c. Function → Supabase: updates `transactions.last_overdue_notified_at = today` (prevents re-sending if the job somehow runs twice in one day)
5. Buyer sees the in-app notification next time they open the app, and (deliverability permitting) receives the email

---

## 14. Activity Diagrams — Core Workflows

Written as start/action/decision/end steps; translate directly into UML
activity diagram notation (● start node, rounded-rectangle actions,
◇ decision diamonds with labeled branches, ⊙ end node). Swimlanes suggested
per diagram where more than one actor/system is involved.

### 14.1 Registration & Login

```
● Start
→ [Action] Student opens Register screen
→ [Action] Student enters email, password, name, university
→ ◇ Decision: does the email end in an accepted university domain (.edu.my)?
    ── No ──→ [Action] Show "Only .edu.my emails accepted" error → (back to entry)
    ── Yes ─→ [Action] Submit to Supabase Auth (create account)
              → [Action] Student completes profile (name, university)
              → [Action] Profile row created in `profiles` (role defaults to "student")
              → [Action] Redirect to Home
⊙ End

--- separately ---

● Start (Login)
→ [Action] Student enters email + password
→ [Action] Submit to Supabase Auth
→ ◇ Decision: credentials valid?
    ── No ──→ [Action] Show error → (back to entry)
    ── Yes ─→ ◇ Decision: profile.suspended == true?
        ── Yes ─→ [Action] Route to Suspended screen (blocked from the app)
        ── No ──→ [Action] Route to Home
⊙ End
```

### 14.2 Create Listing (with optional AI assistance)

```
● Start
→ [Action] Student taps "Create Listing"
→ ◇ Decision: use AI assistance?
    ── Yes ─→ [Action] Provide a rough note and/or up to 3 photos
              → [Action] Backend calls Gemini → suggests title/description/category/price
              → [Action] Suggested fields pre-fill the form (student can still edit)
    ── No ──→ [Action] Student fills all fields manually
→ [Action] Student sets sale/rent type, price, category, condition, uploads photos
→ [Action] Submit → Listing row created in Supabase (source of truth)
→ [Action] Backend embeds the listing (title+description+category) via Gemini
→ [Action] Embedding upserted to Pinecone, keyed by listing ID
→ [Action] Listing now appears in Browse + is searchable semantically
⊙ End
```

### 14.3 Buy / Rent a Listing (payment method decision)

```
● Start
→ [Action] Student views a listing, taps "Buy" (sale) or "Rent" (rent — picks a duration)
→ ◇ Decision: is this student the listing's own seller?
    ── Yes ─→ [Action] Block — "You can't buy your own listing" → ⊙ End
    ── No ──→ continue
→ ◇ Decision: listing type == rent AND student has outstanding late-fee debt?
    ── Yes ─→ [Action] Block — "Settle your outstanding late fee before renting again" → ⊙ End
    ── No ──→ continue
→ [Action] Student chooses payment method: Card (Stripe) or Wallet
→ ◇ Decision: payment method == Wallet?
    ── Yes ─→ ◇ Decision: wallet balance >= total?
        ── No ──→ [Action] Show "Insufficient wallet balance" → (back to method choice)
        ── Yes ─→ [Action] Debit wallet, create transaction row, `escrow_status = held` immediately
    ── No (Card) ─→ [Action] Open Stripe Checkout (hosted page)
              → [Action] Student enters test card, submits
              → [Action] App returns from Checkout, confirms PaymentIntent is `requires_capture`
              → [Action] Create transaction row, `escrow_status = held`
→ [Action] Notify both buyer and seller ("Payment received/successful")
⊙ End
```

### 14.4 QR Handshake (covers both pickup and, for rentals, return)

```
● Start
→ [Action] Giver (seller at pickup, buyer at return) opens "Show QR"
→ [Action] Backend generates a rotating TOTP code tied to the transaction
→ [Action] Receiver scans the QR / types the code
→ [Action] Backend verifies the code
→ ◇ Decision: code valid and not expired?
    ── No ──→ [Action] Show error, allow retry with a fresh code → (back to scan)
    ── Yes ─→ ◇ Decision: which leg is this?
        ── Pickup ─→ ◇ Decision: listing type == sale or rent?
            ── Sale ─→ [Action] status = "completed"
            ── Rent ─→ [Action] status = "active" (rental period begins, due date set)
            → [Action] Capture the held payment (Stripe capture, or wallet credit to seller)
            → [Action] Notify both parties
        ── Return (rent only) ─→ ◇ Decision: is it past `rental_due_date`?
            ── Yes ─→ [Action] Charge late fee (see 14.5) before closing out
            ── No ──→ (no fee)
            → [Action] status = "completed", `return_scanned_at` stamped
            → [Action] Notify buyer of return confirmation (+ late fee amount if any)
⊙ End
```

### 14.5 Charge Late Fee (partial-payment branch)

```
● Start
→ [Action] Triggered by the return-scan leg of 14.4, only if overdue
→ [Action] Compute fee = daily_rate × days_overdue
→ ◇ Decision: buyer's wallet balance >= fee?
    ── Yes ─→ [Action] Debit buyer the full fee, credit seller the full fee
    ── No ──→ [Action] Debit buyer whatever balance they have (partial charge), credit seller that same partial amount
              → [Action] Record the shortfall as `late_fee_owed` on the transaction (tracked debt)
              → [Action] This debt now blocks the buyer from starting new rentals (see 14.3) until settled via "Settle Debt"
→ [Action] Notify buyer of the fee applied
⊙ End
```

### 14.6 Daily Rental Due-Today Reminder (scheduled job)

```
● Start (triggered automatically at 09:00 Asia/Kuala_Lumpur, every day — no human actor)
→ [Action] Query all transactions: type=rent, status=active, rental_due_date=today
→ [Loop] For each matching transaction:
    → ◇ Decision: last_overdue_notified_at == today already?
        ── Yes ─→ [Action] Skip this transaction (already handled today)
        ── No ──→ [Action] Create in-app notification for the buyer
                  → ◇ Decision: does the buyer's profile have an email on file?
                      ── No ──→ (skip email, notification still sent)
                      ── Yes ─→ [Action] Send reminder email via Gmail SMTP
                  → [Action] Stamp `last_overdue_notified_at = today`
⊙ End (loop completes)
```

### 14.7 Admin: Resolve a Report

```
● Start
→ [Action] Admin opens the Reports tab, views all open reports
→ [Action] Admin inspects the reported listing/user and the report reason
→ ◇ Decision: is the report valid / does it warrant action?
    ── Yes, remove listing ─→ [Action] Admin removes the listing (deletes row + Pinecone vector)
    ── Yes, suspend user ──→ [Action] Admin suspends the reported user's account
    ── No, dismiss ────────→ (no moderation action taken)
→ [Action] Admin marks the report "resolved" (stamped with resolved_at)
⊙ End
```

---

*This document reflects the actual, verified state of the codebase as of the
last development session — every feature listed above has been implemented,
tested, and (where applicable) confirmed working end-to-end.*
