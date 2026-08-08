# ADR-0004: UUID Strategy — UUIDv7 (Time-ordered) with Staging Validation Gate

Status: Accepted (with implementation gate)

Date: 2026-08-08

Context
- We require primary keys that are globally unique and index-friendly to reduce B-tree fragmentation and improve insert locality.
- UUIDv7 provides time-ordered UUIDs which improve index locality compared to random UUIDv4.

Decision
- Adopt UUIDv7 for new records as the canonical identifier format across TaxOS, **contingent** on successful validation in the staging environment.

Constraints & Implementation Gate
- Before UUIDv7 appears in production migrations, Sprint 0 must include a validation task:
  - Test generating UUIDv7 in staging using the chosen Postgres environment (Supabase managed Postgres) OR generate UUIDv7 at application layer if DB-side generation is not supported.
  - Validate behavior with Replication, RLS, Outbox and Event Dispatcher flows.
- If DB-side generation via extension is unavailable or incompatible with Supabase managed Postgres, fallback plan:
  - Generate UUIDv7 in application services (Edge functions) or dispatcher libraries prior to writes.

Consequences
- Once validated, use uuid_generate_v7() or app-layer generator for PK default values in migrations.
- Update migration templates to expect UUIDv7 PKs and update any tooling that assumes monotonic IDs.
- Document and test cross-region replication behavior with UUIDv7 values.

Alternatives
- UUIDv4: random UUIDs (no ordering) — accepted fallback if UUIDv7 generation cannot be implemented technically in our stack. Not preferred for index locality.

Rollback strategy
- If validation fails, revert to application-level generator or use UUIDv4 until a DB-level generator is available.
