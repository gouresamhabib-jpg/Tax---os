# TaxOS Database

PostgreSQL schema for Supabase. Sprint 1 implements **accountant multi-tenancy** — each accountant is an isolated tenant.

## Structure

```
database/
├── migrations/     # Versioned SQL migrations (apply in order)
├── seeds/          # Reference data and local dev fixtures
└── policies/       # Reserved for policy-only migrations (optional split)

supabase/
└── config.toml     # Local Supabase CLI configuration
```

## Apply migrations locally

```bash
# Option A: Supabase CLI (copy migrations first)
Copy-Item database/migrations/*.sql supabase/migrations/
supabase start
supabase db reset

# Option B: Direct psql
psql postgresql://postgres:postgres@localhost:54322/postgres \
  -f database/migrations/20260717100000_extensions_and_enums.sql
# ... repeat for each file in order
```

## Migration order

| File | Purpose |
|------|---------|
| `20260717100000_extensions_and_enums.sql` | Extensions + domain enums |
| `20260717100100_shared_functions.sql` | `update_updated_at()` |
| `20260717100200_accountants.sql` | Tenant root + RLS |
| `20260717100300_reference_tables.sql` | Categories |
| `20260717100400_clients.sql` | Taxpayer clients |
| `20260717100500_tax_profiles_returns.sql` | Tax profiles + returns |
| `20260717100600_return_line_items.sql` | Income, deductions, credits |
| `20260717100700_expenses_documents.sql` | Expenses + document vault |
| `20260717100800_invoices.sql` | Invoicing |
| `20260717100900_subscriptions_notifications.sql` | Billing + alerts |
| `20260717101000_triggers_and_auth.sql` | Auth provisioning + totals |
| `20260717101100_storage_policies.sql` | Storage bucket RLS |

## Tenant model

- **Tenant** = one row in `accountants` (1:1 with `auth.users` in Sprint 1)
- **RLS** = `accountant_id = current_accountant_id()` on all business tables
- **Storage paths** = `{accountant_id}/{client_id}/{resource_id}/{filename}`

See `docs/04_DATABASE.md` for the original consumer-app schema; Sprint 1 migrations implement the accountant-centric multi-tenant variant.
