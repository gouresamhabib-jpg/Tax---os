# TaxOS — Existing Database Schema Audit and Migration Readiness

**Document ID:** DOC-15  
**Version:** 0.1  
**Status:** Engineering audit; migration not approved  
**Date:** 24 November 2026  
**Depends on:** DOC-13 Egyptian Firm Product Baseline; DOC-14 Office Tenancy and Membership Model

## 1. Executive finding

The current Supabase migrations are not a neutral foundation that can be converted to firm tenancy by a simple `accountant_id → firm_id` rename.

The inspected schema is explicitly designed around a solo accountant tenant and a US individual income-tax return workflow. TaxOS's confirmed direction is an Egyptian accounting-firm operating system. The current schema therefore has two separate gaps:

1. **Tenant architecture gap:** one authenticated user owns one accountant tenant; there is no office membership model.
2. **Product-domain gap:** core tax tables and enums model US Form 1040 concepts, rather than Egyptian taxpayer entities, tax types, obligations, periods, filing/payment workflows, and ETA-related tracking.

These gaps must be handled separately. The team must not treat a tenancy migration as a product-domain migration.

This audit is based on source migration files in `supabase/migrations/`. It does not establish what is currently deployed to any hosted Supabase environment, nor does it establish live row counts or data quality.

## 2. Source files inspected

The following migration files were inspected:

- `20260717100200_accountants.sql`
- `20260717100300_reference_tables.sql`
- `20260717100400_clients.sql`
- `20260717100500_tax_profiles_returns.sql`
- `20260717100600_return_line_items.sql`
- `20260717100700_expenses_documents.sql`
- `20260717100800_invoices.sql`
- `20260717100900_subscriptions_notifications.sql`
- `20260717101000_triggers_and_auth.sql`
- `20260717101100_storage_policies.sql`

The audit does not assume that the duplicate `database/migrations/` directory is synchronized. That must be checked before selecting a canonical migration source.

## 3. Current schema inventory and findings

| Current object | Current purpose / observed design | Readiness for Egyptian firm product |
|---|---|---|
| `accountants` | One row per auth user; unique `user_id`; combines person/license fields with `firm_name` and address | Must be separated into professional profile and firm tenant |
| `clients` | Individual/business taxpayer-like contact record; includes US-oriented SSN/EIN fields | Requires Egyptian taxpayer/client model and identifier review |
| `tax_profiles` | Filing status, income types, dependents, state of residence | US individual-return concepts; do not reuse as Egyptian tax profile without redesign |
| `tax_returns` | Explicitly described as a 1040 return header; filing status, personal info, computed totals | Not the Egyptian tax-obligation lifecycle |
| `income_entries` | US income categories and federal/state withholding fields | Domain-specific; redesign or retire from Egyptian v1 |
| `deduction_entries` | Tax-return deduction lines | Domain-specific; not a substitute for Egyptian tax adjustments/obligation data |
| `credit_entries` | Tax-return credit lines | Domain-specific; requires legal/product mapping before reuse |
| `return_documents` | Join between tax returns and documents | Relationship concept may remain, but parent integrity must be fixed |
| `expenses` | Client expenses, with optional tax return link | Could be retained only if the Egyptian product needs this accounting concept; tenant and parent constraints need correction |
| `documents` | Client document vault with category, storage path, optional tax return | Reusable concept; storage tenancy and parent constraints need redesign |
| `billing_contacts` | Contacts used as invoice recipients | May be reusable after Egyptian commercial-invoice requirements are defined |
| `invoices`, `invoice_line_items` | Accountant-issued service invoices | Potential office billing feature, but not Egyptian tax invoices/e-invoicing; do not confuse the two |
| `subscriptions` | One subscription per accountant | Move commercial subscription ownership to firm |
| `notifications` | Accountant-scoped in-app notifications | Needs firm and/or user recipient semantics |
| `expense_categories`, `document_categories` | Global lookup tables | Replace US assumptions and seed Egyptian categories where relevant |

### 3.1 Explicit US-domain signals

The current source contains direct US tax concepts, including:

- Migration comments identifying `tax_returns` as a "1040 return header".
- `filing_status` and `state_of_residence`.
- `ssn_last4`, `ssn_vault_ref`, and `ein` on clients.
- `federal_withheld` and `state_withheld` on income entries.
- Income, deduction, and credit line-item tables attached to an individual tax return.
- Expense category comments describing IRS alignment.
- Subscription limits named `returns_per_year`.

These concepts should not be relabeled as Egyptian tax features. Any retained concept needs a documented Egyptian business/legal definition.

## 4. Confirmed tenancy and authorization risks in source

The following are source-level findings. They require runtime tests before assigning exploitability or deployment impact.

### 4.1 One-user-one-tenant constraint

- `accountants.user_id` is UNIQUE.
- `current_accountant_id()` returns one accountant row using `LIMIT 1`.
- Business-table RLS policies compare `accountant_id` to that helper.
- Signup trigger creates one accountant and one subscription for each new auth user.

This cannot support multiple employees in one office or one user belonging to multiple offices.

### 4.2 Parent-child tenant consistency is incomplete

The existing `enforce_client_tenant_match()` trigger checks that a child row's `client_id` belongs to the same `accountant_id`. This does not prove that every other referenced parent belongs to the same tenant.

Examples requiring explicit relational guarantees:

- Income/deduction/credit entries reference `tax_return_id` separately from `client_id`.
- Return-document links reference a return and a document, but the trigger only validates the client relationship.
- Expenses and documents have optional `tax_return_id` values that are not validated against the same tenant/client.
- Invoices reference `billing_contact_id` in addition to `client_id`.
- Notifications can reference a client but have no corresponding tenant-consistency trigger in the inspected migration.
- Invoice line items have a separate invoice tenant trigger; this should be replaced or backed by composite constraints in the target model.

RLS does not replace relational integrity. Use composite firm-aware foreign keys for tenant-owned parent relationships wherever possible.

### 4.3 Privileged updates and functions

- `accountants_update_own` allows a user to update their own accountant row without a column-level restriction. Sensitive fields include `status` and license fields.
- `calculate_return_totals()` is SECURITY DEFINER and updates a return selected by the triggering line item's `tax_return_id`. Its tenant authorization and parent consistency must be reviewed and tested.
- `check_subscription_limit(text, int)` accepts a caller-supplied count. The caller can provide a count that is not independently derived from authoritative database records.
- Every SECURITY DEFINER function must have a reviewed owner, fixed search path, minimal EXECUTE grants, and explicit authorization rules.

### 4.4 Storage path handling

- Current object paths use `{accountant_id}/{client_id}/{resource_id}/{filename}`.
- `storage_accountant_id()` casts the first path segment directly to UUID.
- Malformed path segments can raise cast errors instead of returning a safe denial.
- New paths must use `firm_id` and validate membership plus client/document ownership.
- Legacy object paths must remain supported during a controlled transition; do not move objects in the tenancy schema migration.

### 4.5 RLS policy transition hazard

PostgreSQL permissive policies are combined with OR semantics. Simply adding firm-membership policies while leaving broad legacy accountant policies in place can unintentionally preserve or broaden access.

The cutover plan must explicitly control policy replacement, test authenticated roles, and verify table grants and function EXECUTE privileges. Inventory RLS status, FORCE RLS, policies, grants, owners, and SECURITY DEFINER functions from each actual environment before applying changes.

## 5. Recommended target-domain separation

Build the Egyptian office operating model as the new product core:

- `firms` and `firm_memberships` for office tenancy and employees.
- `clients` for Egyptian taxpayer/client records, with carefully classified legal identifiers.
- `tax_registrations` or equivalent for tax registration profiles and activities.
- `tax_obligations` for VAT, income tax, payroll, withholding tax, stamp tax, real estate tax, and other supported obligation types as approved by product/legal research.
- `obligation_periods` for monthly, quarterly, annual, and event-driven periods.
- `work_items` / `workflow_runs` for assignments, preparation, review, approval, and filing status.
- `filing_events` and `payment_events` for evidence-backed submission/payment tracking.
- `documents` and document links for taxpayer and obligation evidence.
- `tasks`, `calendar_events`, and `notifications` for office operations.
- `firm_subscriptions` for SaaS billing.

The precise entity names and columns are design candidates, not approved schema. Do not create all of them in one migration. First document the domain model and state transitions in a separate reviewable specification.

The current `tax_returns`, `tax_profiles`, and line-item model should be treated as legacy US-domain schema until an explicit keep, replace, archive, or remove decision is made.

## 6. Migration strategy recommendation

Do not combine a destructive US-domain replacement with the firm-tenancy migration.

### Stage 0 — Environment and source-of-truth verification
1. Confirm which migration directory is canonical: `supabase/migrations/` or `database/migrations/`.
2. Compare duplicate files byte-for-byte and document any drift.
3. Obtain schema-only snapshots from local development and each hosted environment.
4. Record migration history, row counts, FK/index/policy/grant inventories, storage buckets, and representative object paths.
5. Establish a disposable local database clone and automated baseline tests.

### Stage 1 — Egyptian domain specification
1. Define Egyptian taxpayer/client types and registration data.
2. Define the v1 tax-obligation catalogue and period rules.
3. Define the obligation lifecycle and permitted transitions.
4. Define assignment, reviewer, approval, filing, and payment evidence.
5. Map each legacy US-domain table to one of: retain, adapt, replace, archive, or remove.
6. Review legal/tax terminology and source-of-truth requirements before implementation.

### Stage 2 — Firm tenancy foundation
1. Create firm and membership structures.
2. Backfill one firm per existing accountant only if actual data and product migration requirements justify preserving those accounts.
3. Add firm identifiers and composite parent relationships to retained business tables.
4. Implement membership-based permissions and column-level protections.
5. Add firm-scoped subscriptions and notifications.
6. Support legacy storage paths during a separately tested transition.

### Stage 3 — New Egyptian operations schema
Implement the approved Egyptian domain in small migrations with RLS and composite foreign keys from the start. Avoid introducing the legacy `tax_returns` model as the foundation of Egyptian obligations.

### Stage 4 — Application cutover and legacy retirement
Only after the new app paths and data migration are tested:
- Switch Flutter queries and Edge Functions to firm-scoped entities.
- Validate all data mappings and counts.
- Rehearse rollback or forward-repair.
- Archive or retire legacy US-domain tables only with explicit approval and verified retention requirements.

## 7. Mandatory pre-migration gates

No executable migration should be merged as production-ready until all gates below are satisfied:

- [ ] Canonical migration directory identified; duplicate migration drift resolved.
- [ ] Actual schema snapshots obtained for local, staging, and production.
- [ ] Current data volume and cross-tenant anomalies measured.
- [ ] Egyptian domain model approved independently from tenancy model.
- [ ] Legacy table disposition documented.
- [ ] Membership permission matrix approved.
- [ ] Composite tenant-aware constraints designed for every retained relationship.
- [ ] RLS, grants, FORCE RLS, and SECURITY DEFINER inventory completed.
- [ ] Storage path migration and rollback strategy tested separately.
- [ ] Integration tests run against disposable PostgreSQL/Supabase-compatible environment.
- [ ] No cross-firm read/write succeeds under authenticated roles.
- [ ] Migration duration, lock impact, and recovery procedure reviewed.
- [ ] Explicit authorization obtained before any hosted staging or production migration.

## 8. Current decision

**Recommendation:** proceed with Egyptian domain modeling and tenancy foundation design; do not yet author or apply a production migration that converts the existing US-oriented schema wholesale.

This audit is documentation only. No database, Supabase project, storage object, application runtime, or hosted environment was changed or tested by this document.
