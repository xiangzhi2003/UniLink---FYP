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
- **API layer:** all backend calls go through `services/api_service.dart` with a
  single configurable base URL so we can switch between local dev and deployed.

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

## Sprint-1 first screens
- `auth/register` — must reject non-`.edu.my` emails before even calling Supabase
- `auth/login`
- `auth/verify_email`
- `profile/edit_profile`
- a home shell with navigation

## Watch out for
- **QR + camera on web:** `mobile_scanner` behaves differently on web vs mobile.
  Test scanning on a real phone; on web, plan a fallback (manual code entry).
- **Image upload size:** compress images before uploading to Supabase Storage.
- **Web CORS:** when calling FastAPI from Flutter web, the backend must allow the
  web origin (CORS middleware). If a web call fails but mobile works, check CORS.
