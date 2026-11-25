# DOC-25 — Flutter Team Management Demo

**Status:** UI prototype only; not production authorization or invitation delivery.

## Purpose

Provide an Arabic-first, English-capable office team screen so the product flow can be reviewed before connecting it to the firm membership RPCs.

## Included

- Office entry point to Team Management.
- Member list with role and membership status.
- Demo actions to change non-owner roles, suspend, reactivate, and revoke memberships.
- Invitation draft form with email validation and selectable non-owner roles.
- Invitation records displayed as pending and marked with a seven-day expiry.
- Arabic and English copy, following the current app locale and direction.
- Widget and repository tests for invitation expiry, local invitation creation, and owner protection.

## Roles

Owner, Administrator, Team Manager, Accountant, Reviewer, Staff, and Read-only.

The demo repository protects the owner from role changes and revocation. It is illustrative only and does not replace server-side authorization.

## Explicit boundaries

- All members and invitations are in-memory sample data and are lost when the app process ends.
- Preparing an invitation does **not** send email, create an Auth user, or issue a real invitation token.
- Role/status changes do not call Supabase and do not create server audit events.
- No firm membership or invitation RPC is called.
- The screen must not be treated as proof of membership or access authorization.
- The app must continue to show the existing authenticated setup-pending state until production membership provisioning and authorization are separately reviewed and approved.

## Next integration gates

1. Review and pass the PR #6 PostgreSQL and disposable local Supabase Auth/RLS invitation tests.
2. Approve a production migration plan from the isolated prototype to versioned migrations.
3. Define a trusted invitation delivery path (Edge Function, provider, redirect/deep link, rate limiting, retry, and delivery audit).
4. Define the current-user membership loading and authorization contract.
5. Integrate narrow RPCs and add integration tests before removing the demo-only label.

No hosted Supabase project or production configuration is modified by this document or its UI prototype.
