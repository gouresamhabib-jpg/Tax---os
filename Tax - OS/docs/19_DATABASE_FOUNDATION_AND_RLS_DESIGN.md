# TaxOS — Database Foundation and RLS Design

**Document ID:** DOC-19  
**Version:** 0.2  
**Status:** MVP access decision confirmed; proposed design, not an approved production migration  
**Date:** 24 November 2026  
**Depends on:** DOC-13, DOC-14, DOC-15, DOC-17

## 1. Objective

Define a safe first database slice for Egyptian accounting offices: office tenancy, membership, and the client master registry. This is a clean target model for a future Supabase implementation. It does not alter, rename, or drop the legacy `accountants` schema.

The accompanying SQL files live under `database/prototypes/`, not a migration directory. They are review and local-test artifacts only.

## 2. Confirmed MVP decisions

1. **Tenant root:** `firms`. A firm is the tenant; an accountant/professional is a person, not a tenant.
2. **Membership:** one row per `(firm_id, user_id)`; role and status are separate. Initial roles: owner, admin, manager, accountant, reviewer, staff, read_only.
3. **Initial owner:** creating a firm creates the creator's owner membership in the same database transaction. The client cannot nominate another user as the initial owner.
4. **Office-wide client visibility (confirmed):** every active member of a firm can view all clients belonging to that firm. Client assignment identifies operational responsibility; it does not restrict visibility or create a security boundary.
5. **Separate responsibility and task ownership (confirmed):** each client can have a designated responsible employee, while individual tasks are assigned independently to their own assignees and, where applicable, reviewers. A client-level responsible employee does not automatically own every task for that client.
6. **Client master:** company and individual records, with identifiers, contacts, and branches in separate child tables.
7. **Identifier handling:** no US SSN/EIN fields. Egyptian tax/VAT/commercial registration identifiers are typed rows, tenant-protected, and not exposed in broad list views. Do not add national-ID storage in this slice.
8. **Tenant integrity:** every client child row carries `firm_id` and references `(firm_id, client_id)`; RLS is not a substitute for relational integrity.
9. **No public storage or ETA integration** in this slice.

## 3. Proposed tables

| Table | Purpose | Tenant key |
|---|---|---|
| `firms` | Accounting office and tenant settings | Root |
| `firm_memberships` | User, firm, role, membership status | `firm_id` |
| `clients` | Taxpayer/client master record | `firm_id` |
| `client_identifiers` | Typed tax/VAT/commercial identifiers | `firm_id` |
| `client_contacts` | Client contact people | `firm_id` |
| `client_branches` | Head office and branch locations | `firm_id` |

`auth.users` remains the authentication source. Professional profile details and employee invitations are intentionally outside this first slice.

### 3.1 Responsibility and task model — next implementation slice

The current SQL prototype does not yet implement assignment or task tables. The following is the agreed product behavior and the proposed direction for the next design increment:

- **Client responsibility:** support one primary responsible employee per client for clear accountability. Store this as a firm-scoped membership reference (or a dedicated assignment record if assignment history is required). The responsible employee must be an active member of the same firm.
- **Supporting employees:** allow additional team members to be associated with a client when needed, without replacing the primary responsible employee.
- **Task ownership:** tasks are separate records linked to a client and firm. Each task has its own assignee; reviewable tasks may also have a separate reviewer. Both must be active members of the same firm.
- **Assignment history:** preserve who assigned/reassigned work, when it happened, and the previous/new assignee for auditability.
- **No access filtering by assignment:** client and task assignments are workflow/accountability metadata only in the MVP. All active firm members retain office-wide client visibility, subject to the firm's eventual role/action permissions.
- **Tenant integrity:** assignment and task rows must enforce firm consistency with composite foreign keys, not rely on Flutter filtering.

Do not treat this conceptual model as an implemented schema. Table names, lifecycle rules, reassignment permissions, and history retention still require a focused design review before SQL is added.

## 4. Authorization rules

- Every normal read/write is scoped by a firm membership with `status = active`.
- The caller is always derived from `auth.uid()`; never accept a user ID from Flutter as proof of identity.
- The selected firm in the UI is a query context only. Database RLS independently checks membership for the row's `firm_id`.
- All active members may read and maintain client records in the initial office-wide MVP. Assignment is not an RLS predicate. Role-sensitive client actions can be narrowed after the permission matrix is finalized.
- Only owner/admin may update firm settings. Membership rows are readable by active firm members but cannot be directly inserted, updated, or deleted by ordinary client sessions.
- Owner membership is created by a database trigger after an authorized firm insert. Ownership transfer and membership administration require dedicated audited functions in a later slice.
- Security-definer helpers use a fixed search path, derive the caller from `auth.uid()`, and have restricted EXECUTE grants.

## 5. Relational integrity

Every client child table has:
- `firm_id NOT NULL`;
- a composite foreign key `(firm_id, client_id) → clients(firm_id, id)`;
- an index beginning with `firm_id` and the parent key.

Future assignment/task tables must similarly include `firm_id` and enforce that both the client and assigned membership belong to that same firm. Identifier uniqueness is scoped to a firm and identifier type, so two different offices may represent the same taxpayer independently. Duplicate active identifiers within one firm are rejected. Validation of official identifier formats is deferred until authoritative Egyptian requirements are documented.

## 6. Migration strategy

This proposal is **not** a direct replacement for the existing SQL. The current legacy migration set creates `accountants` as a one-user tenant and uses `accountant_id` in business tables. The safe path remains expand-and-contract:

1. Inventory each environment and migration history.
2. Review this clean model and agree the role/owner lifecycle.
3. Implement a separate, additive migration that creates firms and memberships.
4. Backfill a one-to-one firm for each legacy accountant using an explicit mapping.
5. Add and verify `firm_id` on existing tables before any app cutover.
6. Test RLS with two firms, multiple members, a user in two firms, and inactive memberships.
7. Cut the app over only after database and application tests pass.
8. Retire legacy columns and policies only under a separately approved destructive migration.

No hosted Supabase migration is authorized by this document.

## 7. Local security test matrix

| Scenario | Expected result |
|---|---|
| Active member reads own firm's clients | Allowed |
| Active member attempts to read another firm's clients | No rows |
| Active member inserts a client for another firm | Rejected by RLS |
| Active member adds a child row with another firm's client ID | Rejected by composite FK |
| Suspended member reads firm data | No rows |
| Unauthenticated request reads tenant data | Denied |
| Ordinary member inserts/changes membership role | Denied |
| Creator creates a firm | Firm and owner membership created atomically |

The prototype test script requires two existing test users in the local Supabase Auth instance. It must be run only against a disposable local database.

## 8. Remaining design decisions before production migration

- Whether firms may have co-owners in v1 (prototype assumes one initial owner, but does not yet enforce a permanent single-owner invariant).
- Exact owner/admin/member permission matrix and who can invite, suspend, or revoke staff.
- Whether client identifiers need field-level encryption or an external secrets vault, based on the deployment threat model.
- Retention and soft-delete policy for clients and official identifiers.
- Detailed client assignment model (primary responsible employee, supporting employees, reassignment history) and task lifecycle/permissions.
- Production migration/backfill, rollback, and legacy storage compatibility details.

## 9. Explicit exclusions

No production migration, data backfill, table rename/drop, Supabase project setting, Storage bucket/policy, ETA connection, or client app database connection is included.
