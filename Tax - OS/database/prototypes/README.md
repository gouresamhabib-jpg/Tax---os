# Database Prototypes

Files in this directory are isolated design and test artifacts.

- They are **not migrations** and are not consumed by Supabase CLI.
- Do not copy them into `database/migrations/` or `supabase/migrations/` without a separately reviewed implementation PR.
- The firm/client prototype creates objects only in the `taxos_prototype` schema and leaves the legacy `public.*` schema unchanged.
- Run only against a disposable local Supabase/PostgreSQL instance.
- The RLS test script requires two existing local Supabase Auth users and rolls back its fixture transaction.
- These files have not been applied to a hosted Supabase project.

A production migration must be additive, reconcile legacy `accountants` records, include a backfill/rollback plan, and pass integration tests under actual Supabase roles before application cutover.
