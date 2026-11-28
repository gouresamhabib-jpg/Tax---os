# TaxOS Flutter application

TaxOS is an Arabic-first, RTL-capable workspace for Egyptian accounting offices.

## Run locally

From this directory:

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=SUPABASE_SCHEMA=taxos_prototype
```

Use only the Supabase publishable key in the browser. Never put a service-role key in Flutter or any client-side build.

## Supabase setup

1. In Supabase Dashboard, open **Project Settings → API → Exposed schemas** and add `taxos_prototype`. Do not expose the `private` schema.
2. Confirm that the `taxos_prototype` tables and RLS policies are present in the staging project.
3. Enable the Auth sign-up method and configure email confirmation and redirect URLs for the web app.
4. Create an account from the TaxOS sign-in screen and confirm the email if required.
5. Create the office. The database trigger creates the first active `owner` membership atomically.
6. Add clients and assign a responsible active office member. Create tasks with an assignee, optional reviewer, priority, and due date.

## Build for desktop browsers

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=SUPABASE_SCHEMA=taxos_prototype
```

The web build is also checked by the Flutter GitHub Actions workflow.

## Current MVP boundaries

- The authenticated workspace reads and writes clients, primary client responsibility, tasks, and task status through Supabase RLS.
- Team membership is read through the firm-scoped member directory RPC when that migration is deployed; otherwise the app falls back to the RLS-protected membership IDs.
- Invitation email delivery, document storage, tax obligation automation, and direct ETA filing are not part of this first usable workspace.
- The unauthenticated demo workspace remains available only when Supabase configuration is omitted. It is not connected to staging data.
