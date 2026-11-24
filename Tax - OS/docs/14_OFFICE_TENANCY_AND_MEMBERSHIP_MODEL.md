# TaxOS — Office Tenancy and Membership Data Model

**Document ID:** DOC-14  
**Version:** 0.1  
**Status:** Proposed architecture for review; not an executable migration  
**Date:** 24 November 2026  
**Depends on:** DOC-13 Egyptian Firm Product Baseline

## 1. Purpose

Define the target office-level tenant model required for TaxOS to serve Egyptian accounting firms with multiple employees, role separation, and strict data isolation.

This document is a design specification only. It does not authorize applying migrations to any Supabase project or changing existing production data.

## 2. Current schema findings

The current migration set under `supabase/migrations/` establishes:

- `public.accountants` as the tenant root.
- `accountants.user_id` as UNIQUE, effectively enforcing one authenticated user per tenant.
- Business tables carry `accountant_id` and RLS calls `current_accountant_id()`.
- `accountants` currently mixes user/professional details (`user_id`, name, email, license) with office details (`firm_name`, address).
- Subscription ownership is tied to `accountant_id`.
- Storage object paths begin with `accountant_id`.
- The client consistency trigger checks a child row's `client_id`, but the schema also contains parent references such as `tax_return_id`, `document_id`, `billing_contact_id`, and `invoice_id` that need their own tenant-consistency guarantees.
- The current accountant self-update policy does not restrict sensitive columns such as account status and license fields.

This design cannot safely express an office owner plus multiple employees.

## 3. Target entity model

### 3.1 Identity and office separation

| Entity | Responsibility | Key fields |
|--------|----------------|------------|
| `auth.users` | Authentication identity | Supabase-managed user ID |
| `accountants` | Individual professional profile | `id`, `user_id`, professional name/contact/license fields |
| `firms` | Tenant / accounting office | `id`, `name`, `legal_name`, `tax identifiers`, address, status, settings |
| `firm_memberships` | User-to-office relationship | `id`, `firm_id`, `user_id`, `role`, `status`, invited/accepted timestamps |
| `firm_invitations` | Controlled onboarding of employees | `firm_id`, normalized email, role, token hash, expiry, inviter, accepted timestamp |
| `firm_subscriptions` | Commercial plan owned by the office | `firm_id`, plan, status, billing provider references |

A user may belong to more than one firm. Each firm may have multiple users. A user's professional profile is not itself a tenant.

### 3.2 Initial roles

Use a controlled role set for v1:

- `owner`: full office administration, membership management, billing, and access to all office work.
- `admin`: office settings and membership administration, excluding ownership transfer and sensitive billing-owner operations.
- `manager`: team workload, assignment, review routing, and office-wide operational visibility.
- `accountant`: assigned client and obligation preparation, document handling, and task updates.
- `reviewer`: review and approval actions; no membership or billing administration.
- `staff`: explicitly granted operational tasks with restricted client/document scope where supported.
- `read_only`: read-only access within explicitly granted office scope.

Membership status is separate from role: `invited`, `active`, `suspended`, `revoked`. Only active memberships authorize normal application access.

The initial design uses a fixed role catalogue and a permission matrix. Custom role builders are deferred until real customer requirements justify their complexity.

### 3.3 Membership constraints

- Unique active membership per `(firm_id, user_id)`; preferably enforce uniqueness for all membership rows and reactivate a revoked row rather than creating duplicates.
- At most one active `owner` membership per firm for the first release, unless co-ownership is explicitly approved later.
- A firm must always retain at least one active owner.
- Ownership transfer is a dedicated audited operation, never an ordinary profile update.
- Invitation acceptance must verify the authenticated user's email against the normalized invited email and must be single-use and time-limited.
- A user cannot assign themselves a higher role or activate their own invitation by changing client-supplied profile metadata.

## 4. Authorization model

### 4.1 Tenant key

The canonical tenant key for business data becomes `firm_id`, not `accountant_id`.

Every firm-owned row must carry a non-null `firm_id` and have a foreign key to `firms(id)`. RLS must authorize access through an active membership in that firm and the required permission.

### 4.2 Permission helpers

Implement reviewed database helpers along these lines (names are proposed, signatures are not final):

- `is_active_firm_member(firm_id)`
- `has_firm_permission(firm_id, permission_key)`
- `can_access_client(firm_id, client_id, permission_key)` when client-level assignment restrictions are enabled.

The helper must derive the caller from `auth.uid()`; never accept a caller user ID from the client as proof of identity. Helpers must have a fixed safe `search_path`, minimal EXECUTE grants, and explicit SECURITY DEFINER ownership/review where required. Avoid recursive RLS by designing the membership lookup carefully and testing it under actual Supabase roles.

### 4.3 Multiple-office membership and active office

RLS must not rely on a single `current_accountant_id()` result or an arbitrary `LIMIT 1`. A user who belongs to two firms must be authorized against each firm only through the corresponding active membership.

The application may maintain a selected-office UI context, but that selection is not an authorization boundary. Every query and mutation must include a firm scope and the database must independently verify membership and permission.

If a future optimization uses an active-firm JWT claim, it must be set only by a trusted server-side process, treated as a selector rather than proof of membership, and revalidated against the membership table. User-editable `user_metadata` must never grant access.

### 4.4 Column-level protection

Do not allow ordinary members to update privileged fields on their own membership, professional profile, or firm. Changes to role, membership status, owner designation, license verification, and firm subscription must use narrowly scoped database functions or server-side operations with audit records.

## 5. Tenant integrity and relational constraints

RLS alone is insufficient because foreign-key checks do not enforce that related records belong to the same firm.

For every tenant-owned parent-child relationship, use composite tenant-aware foreign keys where practical:

1. Add a unique constraint on parent `(firm_id, id)`.
2. Store both `firm_id` and the parent ID on the child.
3. Reference the parent using `FOREIGN KEY (firm_id, parent_id) REFERENCES parent(firm_id, id)`.
4. Add indexes for the referencing columns.
5. Use explicit validation triggers only where composite constraints cannot represent the invariant.

Apply this to at least:

- `tax_profiles` → `clients`
- `tax_returns` → `clients`
- `income_entries`, `deduction_entries`, `credit_entries` → both `tax_returns` and `clients`
- `return_documents` → `tax_returns`, `documents`, and `clients`
- `expenses` and `documents` → `clients` and optional `tax_returns`
- `billing_contacts` → optional `clients`
- `invoices` → `clients` and optional `billing_contacts`
- `invoice_line_items` → `invoices`
- `notifications` → optional `clients` and the intended firm/user recipient.

A child row must not be able to combine a firm ID from one office with a parent ID belonging to another office.

## 6. Client assignment and employee visibility

Firm membership answers whether a person belongs to an office. It does not by itself decide which clients every employee can see.

For the first secure release, choose one of these policies explicitly:

- **Office-wide visibility:** all active members with the relevant permission can access all firm clients. This is simpler and appropriate for small offices.
- **Assigned-client visibility:** access to a client is additionally controlled through a `client_assignments` table, with explicit manager/reviewer exceptions.

Do not implement a hybrid implicitly. The initial recommendation is office-wide visibility with role-based actions for the MVP, while preserving the ability to add assignment restrictions later. This keeps the first release understandable without confusing office isolation with employee workload assignment.

## 7. Storage tenancy

New object paths should use the office tenant key, for example:

`{firm_id}/{client_id}/{document_id}/{filename}`

Storage policies must validate:
- The first path segment is a valid firm UUID.
- The caller has an active membership and the required permission for that firm.
- If a client/document segment is present, it belongs to the same firm.
- The bucket and operation are permitted for the relevant document type.

Do not cast arbitrary path text to UUID without safe validation. Storage service-role operations must validate the same ownership rules in trusted server-side code.

Existing objects under `{accountant_id}/...` must remain readable during migration. Do not bulk move or rename stored objects until a separate, tested storage migration and rollback plan exists.

## 8. Backward-compatible migration plan

Use an expand-and-contract migration. Do not rename or drop existing columns in the first migration.

### Phase A — Inventory and baseline
- Confirm the actual target schema and migration history for each environment.
- Capture row counts, constraints, indexes, RLS policies, grants, functions, and storage object path samples.
- Add automated tests for current behavior and known cross-tenant failures.
- No data changes.

### Phase B — Add office model
- Create `firms`, `firm_memberships`, `firm_invitations`, and `firm_subscriptions`.
- Backfill one firm for each existing `accountants` row.
- Create an active owner membership for the accountant's `user_id`.
- Preserve the mapping `accountants.id → firms.id` in an explicit migration mapping table or stable legacy reference.
- Do not yet change application reads/writes.

### Phase C — Add tenant keys
- Add nullable `firm_id` columns to every existing firm-owned business table.
- Backfill `firm_id` using the legacy accountant-to-firm mapping.
- Verify zero nulls, zero unmapped rows, and zero cross-firm parent references.
- Add composite unique keys and tenant-aware foreign keys as NOT VALID where supported, then validate them after cleanup.
- Add indexes concurrently where the migration environment supports it; plan lock behavior for Supabase/Postgres explicitly.

### Phase D — Authorization cutover
- Add membership-based RLS policies and reviewed helper functions.
- Test with two firms, multiple users per firm, one user in two firms, suspended members, revoked members, and unauthenticated users.
- Keep legacy policies available only as long as required for a controlled dual-read/write window; do not allow permissive legacy policies to OR with new policies and silently broaden access.
- Switch application queries and mutations to `firm_id` and explicit permission checks.
- Revoke unsafe direct column updates and constrain function EXECUTE privileges.

### Phase E — Storage and subscriptions
- Support both legacy accountant-prefixed and new firm-prefixed paths during a controlled transition.
- Introduce firm-owned subscription records and reconcile existing subscriptions.
- Verify storage SELECT/INSERT/UPDATE/DELETE and signed URL behavior under real authenticated roles.

### Phase F — Contract
Only after all application code, tests, rollback windows, and environment evidence are approved:
- Make `firm_id` NOT NULL everywhere.
- Remove legacy `accountant_id` tenant ownership and obsolete helper/policies.
- Retire legacy storage path support after verified object migration.
- Remove the old subscription ownership model.
- Preserve professional profile data in `accountants` or a renamed profile table as an individual entity.

Each phase must be a separately reviewable migration/PR with a documented rollback or forward-repair plan. Destructive contract steps require explicit approval.

## 9. Required security and migration tests

At minimum, automated integration tests must cover:

1. Owner can access their own firm's permitted records.
2. Accountant A cannot read, insert, update, or delete Firm B data.
3. An active employee can access only firms where they have active membership.
4. A user belonging to two firms can access both only through their two memberships.
5. A suspended or revoked member immediately loses access after token/session refresh and cannot use stale client state to mutate data.
6. A user cannot self-promote, self-reactivate, or alter their own role.
7. A firm cannot remove or suspend its final active owner.
8. Invitations are email-bound, expiring, single-use, and resistant to role escalation.
9. Cross-firm client, return, document, billing contact, invoice, and line-item references are rejected by database constraints.
10. SECURITY DEFINER functions do not leak data or allow unauthorized writes; EXECUTE grants are tested for anon/authenticated/service_role.
11. Storage paths with malformed UUIDs, another firm's ID, mismatched client/document IDs, and unauthorized buckets are denied without runtime cast errors.
12. All relevant tables have RLS enabled; FORCE RLS and table-owner/service-role bypass assumptions are explicitly documented and tested.
13. Migration backfill reconciles every existing row and can be safely rerun or resumed.
14. Rollback/forward-repair procedure is rehearsed on a disposable clone before staging.

## 10. Decisions still requiring product confirmation

| Decision | Initial recommendation | Why it matters |
|----------|------------------------|----------------|
| Employee client visibility | Office-wide visibility for MVP | Simplifies first release; assignments remain workload metadata |
| Multiple active owners | One owner initially | Reduces ownership-transfer complexity |
| Custom roles | Defer; fixed role matrix | Keeps permission model testable |
| Client portal identity | Separate future portal membership and policies | Prevents client accounts from inheriting employee permissions |
| Office legal/tax identifiers | Firm profile with validated, optional fields | Exact identifiers and validation need Egyptian product/legal review |
| Accountant licensing | Optional professional profile; not a universal signup gate | Avoids US license assumptions and supports Egyptian office roles |
| Tenant subscription | Firm-owned | Pricing and billing apply to an office, not an individual employee |

## 11. Release gate

No application feature that depends on multi-user office access is ready until:
- DOC-14 is approved,
- the permission matrix is finalized,
- a migration plan is tested against a disposable copy of the current schema,
- cross-tenant and membership tests pass,
- the application has a firm-selection and membership-aware session model.

No staging or production migration is authorized by this document.
