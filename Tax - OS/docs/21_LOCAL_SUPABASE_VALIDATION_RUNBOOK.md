# TaxOS — Local Supabase Validation Runbook

**Document ID:** DOC-21  
**Version:** 0.1  
**Status:** Execution guide; local-only validation  
**Date:** 24 November 2026  
**Depends on:** DOC-19, DOC-20

## 1. Purpose

The PostgreSQL 16 GitHub Actions compatibility job now executes the firm/client and client-assignment prototypes with a minimal Auth compatibility shim. This runbook defines the next validation gate against the actual local Supabase stack, including its Auth schema, roles, and `auth.uid()` implementation.

This is a disposable local test only. Do not use a hosted or production Supabase project.

## 2. Prerequisites

- Docker Desktop (running).
- Supabase CLI.
- PostgreSQL client (`psql`).
- A separate scratch directory for the local Supabase project.

Do not run `supabase init` in the TaxOS repository root as part of this test. The repository contains legacy migration material that is outside this prototype's scope.

## 3. Start an isolated local Supabase stack

Create a scratch directory outside the TaxOS repository and initialize Supabase there:

```bash
mkdir taxos-supabase-validation
cd taxos-supabase-validation
supabase init
supabase start
```

Confirm the local services and database URL:

```bash
supabase status
```

Use the local database URL shown by the CLI (normally `postgresql://postgres:postgres@127.0.0.1:54322/postgres`).

## 4. Create two disposable Auth users

1. Open the local Supabase Studio URL printed by `supabase status` (normally `http://127.0.0.1:54323`).
2. Open Authentication → Users.
3. Create two disposable users.
4. Copy both user UUIDs. These are the values for `user_a` and `user_b`.

Do not use real client or employee accounts.

## 5. Apply the isolated prototypes

From the TaxOS repository root, set the local database URL and the two user UUIDs:

```bash
export TAXOS_LOCAL_DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
export TAXOS_TEST_USER_A='<first-local-auth-user-uuid>'
export TAXOS_TEST_USER_B='<second-local-auth-user-uuid>'
```

Apply the prototype SQL in order:

```bash
psql "$TAXOS_LOCAL_DB_URL" --set ON_ERROR_STOP=1 \
  --file "Tax - OS/database/prototypes/20261124_firm_client_registry.sql"

psql "$TAXOS_LOCAL_DB_URL" --set ON_ERROR_STOP=1 \
  --file "Tax - OS/database/prototypes/20261124_client_assignments_and_work_items.sql"
```

Run both RLS test scripts:

```bash
psql "$TAXOS_LOCAL_DB_URL" --set ON_ERROR_STOP=1 \
  --set user_a="$TAXOS_TEST_USER_A" \
  --set user_b="$TAXOS_TEST_USER_B" \
  --file "Tax - OS/database/prototypes/20261124_firm_client_registry_rls_tests.sql"

psql "$TAXOS_LOCAL_DB_URL" --set ON_ERROR_STOP=1 \
  --set user_a="$TAXOS_TEST_USER_A" \
  --set user_b="$TAXOS_TEST_USER_B" \
  --file "Tax - OS/database/prototypes/20261124_client_assignments_and_work_items_rls_tests.sql"
```

Each test script wraps its fixtures in a transaction and rolls them back. The isolated `taxos_prototype` schema remains in the disposable local database for inspection.

## 6. What must pass

- Firm creation provisions the creator as the initial active owner.
- Active firm members can see all clients in their own firm; suspended and cross-firm access is denied.
- Cross-firm child references are rejected by tenant-aware foreign keys.
- Client primary assignment is unique; reassignment preserves history.
- Tasks require active same-firm assignees and optional distinct reviewers.
- Assignees can update progress but cannot reassign tasks or edit manager-controlled details.
- Assignment history is trigger-written and cannot be directly modified by authenticated users.
- Completion timestamps are set and cleared by task status transitions.

Record the CLI version, local Supabase version, PostgreSQL version, test output, and any deviations before promoting any prototype into migration design.

## 7. Cleanup and safety

After collecting the test output:

```bash
supabase stop --no-backup
```

- Do not copy prototype SQL into `database/migrations/` or `supabase/migrations/`.
- Do not point this runbook at `taxos-staging` or any hosted Supabase project.
- Do not use real taxpayer data.
- A passing local test does not approve production migration, legacy backfill, or app cutover.

## 8. Next implementation gate

Only after this local Supabase validation passes should the next increment add the Flutter Supabase client, environment configuration, firm bootstrap, authenticated session handling, and database-backed client/work-item repositories. The UI should keep demo mode separate from authenticated office data.
