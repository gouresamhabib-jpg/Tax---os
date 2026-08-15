# Sprint 0 Validation Tasks

This document lists the mandatory validation tasks for Sprint 0 prior to enabling production migrations or unlocking UUIDv7.

1. Environment Provisioning
- Provision staging Supabase instance equivalent to production plan (same Postgres version).
- Provision NATS JetStream dev cluster (3-node recommended) or managed service.
- Provision AWS Secrets Manager & KMS test keys.

2. Outbox & Dispatcher Sanity Test
- Implement and run a non-production dispatcher that reads Outbox rows and publishes to NATS.
- Validate at-least-once delivery, idempotency handling, and DLQ behavior.

3. UUIDv7 Generation Test
- Task A: Attempt DB-side uuidv7 generation (extension or UDF) in staging.
  - If an extension exists and is acceptable, evaluate replication & index performance.
- Task B (fallback): Implement application-level uuidv7 generation and exercise full write-flow with outbox/dispatcher.
- Acceptance criteria:
  - Generated IDs are time-ordered; index insertion locality improves (benchmarks to be captured).
  - No replication or outbox issues observed.

4. NATS JetStream Integration Test
- Publish/subscribe latency & throughput tests.
- Consumer checkpointing and replay test.
- DLQ enqueue/dequeue and replay scenarios tested.

5. RLS Policy Smoke Tests
- Create test tenants and users with different roles.
- Validate that RLS policies prevent cross-tenant access for all tenant-aware tables.

6. Secrets Access Test
- Worker obtains secret via AWS SM (with role assumed), accesses KMS to decrypt DEK.
- Logs of secret access recorded in CloudTrail.

7. Health & Observability Tests
- Instrument Edge functions and a Worker with OpenTelemetry and validate trace propagation across APIGW -> Edge -> DB -> Dispatcher -> Worker -> EventBus.

Acceptance Gates
- All tasks completed and verified in staging without unacceptable security or stability findings.
- UUIDv7 validation either successful (DB-side) or fallback plan approved (app-generated UUIDv7).

Owners: Architecture Team / Platform / SRE
