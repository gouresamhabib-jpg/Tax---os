# Flutter Supabase Bootstrap

**Document ID:** DOC-22  
**Version:** 0.1  
**Status:** Foundation implemented; no authenticated data access yet  
**Date:** 24 November 2026  
**Depends on:** DOC-19, DOC-20, DOC-21

## 1. Purpose

The Flutter app can now initialize the Supabase client from compile-time environment values. When either value is missing, the app remains in its clearly labelled local demo mode and does not attempt a network connection.

The implementation uses the stable `supabase_flutter 2.18.3` package. This release requires Dart 3.9 or later; the app SDK constraint has been updated accordingly.

## 2. Configuration

The app reads two compile-time values:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Do not commit real project values to source control. A Supabase publishable key is intended for client applications, but it must always be protected by correctly configured RLS and least-privilege grants. Never put a `service_role` key or database password in a Flutter build.

## 3. Local development

Start the disposable local Supabase project using the DOC-21 runbook. Then run Flutter with the local project URL and its publishable/anon key.

For desktop or iOS Simulator:

```bash
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY='<local-publishable-key>'
```

For the Android Emulator, forward the local Supabase port to the emulator loopback first:

```bash
adb reverse tcp:54321 tcp:54321
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY='<local-publishable-key>'
```

The stable v2 client accepts local loopback HTTP. Use HTTPS for hosted environments and physical-device testing; do not weaken transport security in the app.

## 4. Current behavior and limits

- `SupabaseBootstrap.initialize()` returns `false` and does nothing when configuration is absent.
- With both values present, it initializes one Supabase Flutter client before `runApp`.
- The UI remains in demo mode. No login, firm onboarding, client queries, task writes, storage, or realtime subscriptions are wired yet.
- The prototype schema lives in `taxos_prototype` and is not a deployable migration. Do not point the app at a hosted project until a separately reviewed migration and environment setup are approved.
- Local Supabase CI validates the SQL/Auth/RLS layer; the Flutter bootstrap test validates the no-config demo fallback. A full mobile-device connectivity test remains a separate gate.

## 5. Next gate

After the prototype is promoted through a reviewed migration PR, implement authentication screens and session routing, then a server-authorized firm bootstrap. Only after that should the app switch from in-memory repositories to database-backed repositories.
