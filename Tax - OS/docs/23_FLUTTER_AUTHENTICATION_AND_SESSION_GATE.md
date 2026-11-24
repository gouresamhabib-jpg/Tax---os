# DOC-23 — Flutter Authentication and Session Gate

**Status:** Implemented as a review-only application increment  
**Scope:** Supabase email/password authentication and client-side session routing  
**Does not authorize:** hosted configuration changes, user provisioning, production database changes, or firm onboarding

## Behavior

- When Supabase compile-time configuration is absent, the app remains in the clearly identified local demo workspace.
- When Supabase is configured but no session exists, the app shows the Arabic-first / English sign-in screen.
- Sign-in uses Supabase Auth email/password credentials.
- Password reset requests use Supabase Auth `resetPasswordForEmail`.
- The UI does not expose public sign-up. Accounts must be provisioned through an approved administrative process.
- Auth state changes are observed through `onAuthStateChange`; the current persisted session is also checked on startup.
- An authenticated user is shown an **Office setup pending** screen, not demo client records. This is deliberate: the firm/membership production schema has not been promoted from the isolated prototype and the app must not infer a firm or query prototype tables.
- The pending screen exposes sign-out.

## Security boundaries

- The Flutter app uses only the Supabase publishable key. A service-role key must never be shipped in the client.
- Authentication proves the identity of a user; it does not prove that the user belongs to a firm or authorize access to firm data.
- No client, task, obligation, document, or membership queries are introduced in this increment.
- No hosted Supabase settings, users, migrations, storage, or data were changed.
- The current password-reset increment requests an email only. A production deep-link / password-update completion route and approved redirect URL still need to be configured and tested before enabling password recovery for users.

## Required next gates

1. Approve and promote a reviewed firm/membership migration through a separate PR and explicit deployment approval.
2. Define the invitation/provisioning process and the permitted firm roles.
3. Add a server/RLS-backed membership resolver; never trust a client-supplied firm ID.
4. Route authenticated users to the workspace only after an active firm membership is confirmed.
5. Configure and test password-reset deep links, email templates, allowed redirect URLs, and session recovery on Android/iOS.
6. Add integration tests against a disposable local Supabase instance for sign-in, persisted session, sign-out, invalid credentials, and recovery flow.

## Local development

Continue to use the existing DOC-22 compile-time configuration guidance. Use a publishable key only. Do not commit secrets or put a service-role key in `--dart-define` values distributed with the app.
