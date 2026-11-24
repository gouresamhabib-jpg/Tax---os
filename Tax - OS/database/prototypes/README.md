# Database Prototypes

Files in this directory are isolated design and test artifacts.

- They are **not migrations** and are not consumed by Supabase CLI.
- Do not copy them into `database/migrations/` or `supabase/migrations/` without a separately reviewed implementation PR.
- The firm/client prototype creates the isolated `taxos_prototype` schema and leaves legacy `public.*` objects unchanged.
- Apply the prototype files in this order on a disposable local Supabase/PostgreSQL instance:
  1. `20261124_firm_client_registry.sql`
  2. `20261124_client_assignments_and_work_items.sql`
  3. `20261124_firm_invitation_lifecycle.sql`
- Run the matching local test scripts after all three schema files:
  1. `20261124_firm_client_registry_rls_tests.sql`
  2. `20261124_client_assignments_and_work_items_rls_tests.sql`
  3. `20261124_firm_invitation_lifecycle_rls_tests.sql`
- The first two suites require two existing local Supabase Auth users. The invitation suite requires three: firm owner, second firm member/admin, and invitee. All test fixtures roll back.
- The assignment extension adds client responsibility, operational work items, and trigger-written assignment history. It is not a tax-obligation or formal approval workflow.
- The invitation extension adds owner/admin-controlled invitations, confirmed-email acceptance, role administration, suspension/revocation, and append-only audit events. It does not send invitation email; delivery requires a separately reviewed trusted backend/Edge Function.
- GitHub Actions runs all SQL prototypes and RLS scripts twice: first on PostgreSQL 16 with the isolated `test_support/postgres_auth_stub.sql`, then on a disposable local Supabase stack using three real Auth users created through the local Auth API. The shim is a fast compatibility layer; the local Supabase job validates actual Auth schema, roles, and `auth.uid()` behavior.
- These files have not been applied to a hosted Supabase project. Passing local Supabase CI does not approve production migrations, legacy backfill, email configuration, or application cutover.

A production migration must be additive, reconcile legacy `accountants` records, include a backfill/rollback plan, and pass integration tests under actual Supabase roles before application cutover.
