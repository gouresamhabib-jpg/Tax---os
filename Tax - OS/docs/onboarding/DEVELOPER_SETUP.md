# Developer Setup

> **Status:** Placeholder

## Prerequisites

- Flutter SDK (stable)
- Supabase CLI
- Git

## Steps

1. Clone repository
2. `cd apps/mobile && flutter pub get`
3. Copy `.env.example` to `.env` (when available)
4. Run Supabase locally: `supabase start`
5. Apply migrations from `database/migrations/`
6. `flutter run`

## TODO

- [ ] Add `.env.example`
- [ ] Add IDE setup (VS Code / Cursor extensions)
- [ ] Add troubleshooting section
