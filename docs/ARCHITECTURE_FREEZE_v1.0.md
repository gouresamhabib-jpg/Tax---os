# TaxOS Architecture Freeze v1.0

Date: 2026-08-08

This commit freezes the TaxOS architecture (v1.0). The architecture and documentation included in this branch are considered the authoritative design for implementation. Any future material changes must be made through a new ADR and approved by architecture owners.

Core Finalized Decisions
- API Gateway mandatory for all incoming traffic (auth, WAF, rate-limiting, structured logging, request/correlation id propagation).
- Edge Functions for lightweight request/response logic only.
- Workers (OCR, AI/Embeddings, Connectors, Scheduler, Billing, Indexing) are separate autoscalable services.
- Outbox + Event Bus (NATS JetStream) hybrid event-driven architecture.
- Multi-tenant architecture from day one: tenant_id in all tenant-aware entities, RLS enforced at DB.
- UUIDv7 adopted as primary identifier format conditional on successful staging validation (Sprint 0 validation required).
- Secrets: AWS Secrets Manager + AWS KMS (customer-managed keys available for Enterprise tenants).
- Connectors are plugin-based; Egypt plugin and other country packs are external to core.
- AI adapter abstraction for provider-agnostic integration and RAG support.

Included Documents (this branch)
- ADRs: ADR-0003 (NATS), ADR-0004 (UUIDv7), ADR-0005 (AWS Secrets Manager)
- Docs skeleton and core freeze summary
- Sprint 0 validation tasks (UUIDv7 test, Event Bus sanity checks)

Next Steps
- Implement Sprint 0 tasks (infrastructure, auth, RLS, Outbox, Event Bus wiring, UUIDv7 staging test).
- On completion of Sprint 0 validation tasks the UUIDv7 ADR becomes actionable for migrations.

Architecture Freeze Conditions
- This freeze remains valid provided that any subsequent architecture modification follows the ADR process (proposal, impact analysis, approval).
- Changes that break compatibility require explicit deprecation and migration plans.

Branch created: arch/freeze-2026-08-08
