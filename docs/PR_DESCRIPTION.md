# PR: TaxOS Architecture Freeze v1.0 — Documentation Freeze

Branch: `arch/freeze-2026-08-08`
Target: `main`

## Title
TaxOS Architecture Freeze v1.0 — Documentation Freeze

## Summary
This PR contains the TaxOS Architecture Freeze artifacts and documentation. It **freezes the architecture and documentation** for TaxOS v1.0. The freeze includes ADRs, OpenAPI specification (split components), event model, connector SDK spec, plugin spec for Egypt, migration templates, RLS policy specifications, CI skeletons, and sprint-0 validation plan.

**Important:** This is a Documentation Freeze — not a Production Readiness freeze. Several validation gates must be completed in Sprint 0 (listed under Architecture Freeze Gates) before production migrations or runbooks are executed.

## Included
- `adr/` — Architecture Decision Records (ADR-0003, ADR-0004, ADR-0005, etc.)
- `openapi/` — OpenAPI 3.1 (main + components + examples)
- `docs/` — architecture, sprint-0 plan, production readiness checklist, DR runbook, incident response, event catalog
- `db/migrations-templates/` — migration templates (non-executable)
- `db/rls_policies/` — RLS pseudo-policy specifications
- `docs/sprint-0/SPRINT0_PLAN.md` — Sprint 0 validation plan and gates
- `apps/` — skeletons for Flutter, Edge Functions, Workers, Connectors
- `ci/` — CI validation job skeletons

## Architecture Freeze Gates (Sprint 0 mandatory validations)
1. UUIDv7 staging validation (DB-side or app-side fallback)
2. NATS JetStream sanity (publish/subscribe, replay, DLQ, consumer scaling)
3. AWS Secrets Manager + KMS IAM validation and CloudTrail logging
4. RLS tenant-isolation smoke tests (no cross-tenant leakage)
5. Migration dry-run & rollback validation in staging
6. Backup & restore drill validation

The above gates are documented in `docs/sprint-0/SPRINT0_PLAN.md` and are **required** prior to any production migrations or enabling UUIDv7 for production.

## How to review
1. Review ADRs in `adr/` and ensure decisions reflect stakeholder approval.
2. Review `openapi/` and pick a few critical endpoints (companies, obligations, documents, connectors) to validate request & response examples.
3. Verify RLS policy docs under `db/rls_policies/` to ensure no cross-tenant access path is overlooked.
4. Check `docs/sprint-0/SPRINT0_PLAN.md` and confirm owners and timeline.

## Merge policy
- Merge once architecture owners (Architecture, Platform, Security, Product) sign-off on the PR.
- After merge: start Sprint 0 validation tasks. UUIDv7 will be enabled for migrations only after Gate 1 passes.

## Post-merge
- Any architectural change must be proposed via ADR and approved before implementation.

---

Please review and approve to finalize the documentation freeze and to start Sprint 0 validation work.
