# Sprint 0 Plan (gates and validation tasks)

Location: docs/sprint-0/SPRINT0_PLAN.md

This file contains the Sprint 0 plan and the mandatory validation gates required before moving from Architecture Freeze to Implementation phases. It is included in the Architecture Freeze PR.

Sprint 0 Objectives
- Validate UUIDv7 generation approach in staging (DB-side or app-side fallback).
- Provision and sanity-test NATS JetStream for event streaming (replay, DLQ, durable consumers).
- Implement and validate Outbox -> Dispatcher -> NATS -> Worker end-to-end flow.
- Validate RLS policies prevent cross-tenant data access in staging.
- Validate AWS Secrets Manager + KMS IAM and secret retrieval for Workers and Edge functions.
- Run migration dry-run and rollback test in staging.
- Perform backup & restore drill in staging and validate restore procedures.

Sprint 0 Deliverables
1. Infrastructure & Access
   - Staging Supabase instance with Postgres + Storage
   - NATS JetStream staging cluster (3-node)
   - AWS Secrets Manager and KMS keys (staging)

2. Outbox & Dispatcher
   - Dispatcher prototype that reads outbox and publishes to NATS.
   - Worker consumer for a sample event (DocumentUploaded -> OCRWorker) that acknowledges and writes OCRCompleted.

3. UUIDv7 Validation
   - Test DB-side generator (if extension available) and benchmark index locality.
   - If DB extension not available, implement app-layer generator; measure latency and DB behavior.
   - Produce short report with recommendation (DB-side vs app-side) and update ADR-0004.

4. NATS JetStream Tests
   - Throughput & latency tests (publish/subscribe)
   - Replay & DLQ test
   - Consumer scaling test: multiple durable consumers

5. RLS Smoke Tests
   - Create at least three test tenants and users with different roles and run a defined test matrix (SELECT/INSERT/UPDATE/DELETE) against all tenant-aware tables.
   - Test cases and results logged in repo under /test/rls/

6. Secrets Flow Test
   - Worker retrieves secret via AWS SM using role-based access, decrypts using KMS, and logs access.
   - Validate CloudTrail logs for secret access.

7. Migration Dry-run & Backup/Restore
   - Run migration dry-run using migration templates, validate schema expectations.
   - Test restore from the staging snapshot and validate application connectivity.

Sprint 0 Acceptance Criteria (Gates)
- Gate 1: UUIDv7 staging validation completed and recommendation documented.
- Gate 2: NATS JetStream sanity verification: publish/subscribe/replay tests passed.
- Gate 3: Outbox -> Dispatcher -> NATS -> Worker end-to-end flow validated without data loss (idempotency/dedup verified).
- Gate 4: AWS Secrets Manager + KMS access and logging validated.
- Gate 5: RLS tenant isolation smoke tests passed (no cross-tenant leakage).
- Gate 6: Migration dry-run and restore tests successful.

If any gate fails, create an incident ticket and/or ADR for remediation and do not promote the relevant components to production until remediation and retest are successful.

Owners
- Platform / SRE: infra, NATS, KMS, backups
- Backend: outbox & dispatcher, UUID tests
- Security: RLS tests, secrets policies
- Product: verify acceptance criteria

Timeline
- Sprint 0: 2–4 weeks depending on infra availability and backlog.

