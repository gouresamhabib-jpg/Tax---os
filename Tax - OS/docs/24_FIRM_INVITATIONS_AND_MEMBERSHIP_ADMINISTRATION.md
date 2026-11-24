# DOC-24 — Firm Invitations and Membership Administration

**Status:** Proposed local prototype; not a production migration  
**Date:** 24 November 2026  
**Depends on:** DOC-19, DOC-20, and the firm/client registry prototype

## 1. Purpose

Define how an Egyptian accounting office owner/admin adds staff, assigns an initial role, changes roles, and suspends or revokes membership. Authentication and firm authorization remain separate: a valid TaxOS login alone does not grant access to an office.

The SQL and test files are isolated under `database/prototypes/`. They do not alter hosted Supabase or the legacy schema.

## 2. Roles and authority

| Role | Invite members | Assign/change roles | Suspend/revoke members | Office data |
|---|---|---|---|---|
| Owner | All supported roles except another owner | All roles except changing owner | All non-owner members | Full firm administration |
| Admin | Manager, accountant, reviewer, staff, read-only | Non-admin roles only | Non-admin members only | Firm-wide operational access |
| Manager | No | No | No | Firm-wide read; operational assignments/tasks per DOC-20 |
| Accountant | No | No | No | Firm-wide read; assigned work progress |
| Reviewer | No | No | No | Firm-wide read; review/progress |
| Staff | No | No | No | Firm-wide read; assigned work progress |
| Read-only | No | No | No | Firm-wide read only |

- The initial owner is provisioned atomically when a firm is created.
- A second owner is not supported by this prototype.
- Only the owner can appoint an admin or manage an existing admin.
- Admins cannot change their own role/status, appoint admins, or manage owner/admin memberships.
- Members cannot change their own role or membership status.
- Owner membership cannot be modified through the member administration RPCs.
- Revocation is terminal in this prototype. A revoked person must be re-invited through a separately designed re-onboarding process; the unique firm/user membership row is not silently reused.
- Suspended membership can be reactivated by an authorized owner/admin, subject to the same admin boundary.

## 3. Invitation lifecycle

1. An active owner/admin creates an invitation for an email address and permitted role.
2. Invitation expires after seven days. One pending invitation per firm/email is allowed.
3. The invited person signs in or creates an account through the separately approved account-provisioning process.
4. Acceptance requires a confirmed Supabase Auth email matching the invited email exactly (case-insensitive).
5. The database atomically creates an active firm membership and marks the invitation accepted.
6. Acceptance is single-use. Expired and revoked invitations cannot be accepted.
7. Owner/admin can revoke pending invitations.

An invitation does not itself create a Supabase Auth user. Public sign-up remains outside this design.

## 4. Email delivery boundary

The SQL prototype records and manages invitation state; it does **not** send email or create an invitation deep link. A future trusted Edge Function must authenticate the requesting user using their JWT, call the database authorization path rather than trust a client-supplied role/firm, deliver the opaque invitation reference through an approved email provider, avoid logging invitation URLs or tokens, and use approved redirect URLs and a controlled deep-link route.

The acceptance RPC independently verifies the signed-in user's confirmed email. Do not put a Supabase service-role key in Flutter. Email provider, templates, retry/outbox, rate limits, abuse controls, and deep-link handling remain open implementation gates.

## 5. Audit and security

- Membership and invitation writes are revoked from direct authenticated table access.
- Narrow SECURITY DEFINER functions derive the actor from `auth.uid()`, use fixed search paths, and have restricted EXECUTE grants.
- Invitation rows are visible only to owner/admin or the matching confirmed invitee email.
- Membership administration events are append-only to authenticated clients and visible only to owner/admin.
- Acceptance locks the invitation row to prevent concurrent/repeated acceptance.
- The invitee must have a confirmed email address; an invitation UUID alone is insufficient.
- RLS on firm data continues to require active membership. Suspension/revocation therefore removes access without deleting work history.
- Client assignment remains operational responsibility, not a data-visibility restriction.

## 6. Local tests

The new RLS test script checks owner invite creation, manager restrictions, invitee-only visibility, confirmed-email matching, single-use acceptance, owner-only admin appointment, admin role-management boundaries, self/owner protection, suspension/reactivation/revocation, invitation revocation/expiry, and immutable membership event history.

The disposable local Supabase CI job uses three Auth users. The PostgreSQL compatibility shim is only a fast test layer; the actual local Supabase job is the authoritative compatibility check for Supabase Auth roles and schema.

## 7. Explicit exclusions and next gates

- No invitation email is sent in this prototype.
- No public sign-up, password-reset deep-link completion, user provisioning UI, or Flutter team-management screen is included.
- No hosted database, Auth user, email provider, redirect URL, or project setting is changed.
- Before production: review SECURITY DEFINER ownership/bypass-RLS assumptions, email verification lifecycle, rate limiting, invite resend semantics, role matrix, owner transfer/recovery, audit retention, and migration/backfill plan.
- Promote to a production migration only through a separate reviewed PR and explicit deployment approval.
