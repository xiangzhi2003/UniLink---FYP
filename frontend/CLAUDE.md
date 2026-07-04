# CLAUDE.md — Frontend (Flutter)

> Flutter-specific conventions. The root `../CLAUDE.md` has the full project context — read it first.

## What lives here
The Flutter app: a single Dart codebase targeting **mobile (Android/iOS) and web**.
It talks to the FastAPI backend over HTTP and to Supabase via the Supabase Flutter SDK.

## Conventions

- **Responsive by default.** Every screen must work on a phone AND a wide web
  browser. Use `LayoutBuilder` / `MediaQuery` to switch between a mobile layout
  (single column, bottom nav) and a web layout (wider, side nav or centered
  content). Test both regularly — not at the end.
- **State management:** use a simple, consistent approach (Provider or Riverpod).
  Pick one at the start and stick to it. Don't mix.
- **Folder purpose:**
  - `models/` — plain Dart data classes (Listing, UserProfile, Transaction, Message)
  - `screens/` — one folder per feature area, screens only
  - `services/` — all external calls (API, Supabase, Stripe). Screens never call
    HTTP directly; they go through a service.
  - `widgets/` — reusable UI pieces (buttons, cards, list tiles)
  - `config/` — Supabase init, backend base URL, environment values
- **No secrets in code.** The backend base URL and Supabase anon key live in
  `config/`. Never hardcode private keys in the Flutter app.
- **API layer:** when a screen needs the FastAPI backend (not just Supabase),
  route it through a dedicated file in `services/` with a single configurable
  base URL — screens never call HTTP directly. No such file exists yet since
  nothing has needed the backend beyond auth (which goes straight to
  Supabase); add one when a real backend call is needed (Sprint 2+).

## Key packages (add as needed, don't over-install upfront)

| Purpose | Package |
|---------|---------|
| Supabase | `supabase_flutter` |
| HTTP calls | `http` or `dio` |
| QR display | `qr_flutter` |
| QR scanning | `mobile_scanner` |
| Image pick/upload | `image_picker` |
| State management | `provider` or `flutter_riverpod` |
| Cached images | `cached_network_image` |

## Sprint-1 screens (done)
- `auth/welcome` — landing screen (Get Started / I already have an account)
- `auth/register` — two-step wizard (account details, then profile); rejects
  non-`.edu.my` emails client-side before ever calling Supabase; the account
  is only created once both steps are filled in
- `auth/login`
- `auth/forgot_password` / `auth/reset_password` — email a reset link,
  completed on whichever device opens it (no confirmation-email step exists;
  it was deliberately dropped — `.edu.my` domain gating is the only check)
- `profile/edit_profile` — also doubles as `AuthGate`'s fallback for a
  signed-in user with no profile row yet
- `home/home_shell` — placeholder home with responsive nav; real marketplace
  content is Sprint 2

## Watch out for
- **QR + camera on web:** `mobile_scanner` behaves differently on web vs mobile.
  Test scanning on a real phone; on web, plan a fallback (manual code entry).
- **Image upload size:** compress images before uploading to Supabase Storage.
- **Web CORS:** when calling FastAPI from Flutter web, the backend must allow the
  web origin (CORS middleware). If a web call fails but mobile works, check CORS.
