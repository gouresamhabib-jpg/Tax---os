# Database Prototypes

Files in this directory are isolated design and test artifacts.

- They are **not migrations** and are not consumed by Supabase CLI.
- Do not copy them into `database/migrations/` or `supabase/migrations/` without a separately reviewed implementation PR.
- The firm/client prototype creates the isolated `taxos_prototype` schema and leaves legacy `public.*` objects unchanged.
- Apply the prototype files in this order on a disposable local Supabase/PostgreSQL instance:
  1. `20261124_firm_client_registry.sql`
  2. `20261124_client_assignments_and_work_items.sql`
- Run the matching local test scripts after both schema files:
  1. `20261124_firm_client_registry_rls_tests.sql`
  2. `20261124_client_assignments_and_work_items_rls_tests.sql`
- Each test script requires two existing local Supabase Auth users and rolls back its fixture transaction.
- The assignment extension adds client responsibility, operational work items, and trigger-written assignment history. It is not a tax-obligation or formal approval workflow.
- These files have not been applied to a hosted Supabase project and have not yet been executed against a local PostgreSQL/Supabase instance.

A production migration must be additive, reconcile legacy `accountants` records, include a backfill/rollback plan, and pass integration tests under actual Supabase roles before application cutover.
