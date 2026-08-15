# ADR-0004: UUID Strategy — UUIDv7 (Time-ordered) with Staging Validation Gate

Status: Accepted with implementation gate

Date: 2026-08-08 (updated: 2026-08-XX)

Context
- We require primary keys that are globally unique and index-friendly to reduce B-tree fragmentation and improve insert locality.
- UUIDv7 provides time-ordered UUIDs which improve index locality compared to random UUIDv4.

Decision (update)
- Adopt UUIDv7 as the canonical identifier format for new records in TaxOS.
- Based on Sprint‑0 Gate‑1 verification in staging, UUIDv7 generation will be performed at the application layer (application-side UUIDv7 generator). A DB-native uuid_generate_v7() function is not required.
- Store UUIDv7 values in PostgreSQL `uuid` columns.

Constraints & Implementation Gate (updated)
- Sprint‑0 Gate‑1 validated application-side UUIDv7 generation (see Sprint‑0 test results). Because the tested Supabase Postgres environment did not provide a DB-native uuid_generate_v7() function, the project will use an application-layer generator for UUIDv7.
- Production migrations that introduce UUIDv7 as the canonical ID format remain gated. Before enabling UUIDv7 in production migrations, replication validation must be completed once a read-replica or replication destination is available in staging — replication validation remains deferred until such a staging replica exists.
- Maintain compatibility for legacy UUIDv4 records; the system must accept and handle UUIDv4 legacy identifiers where they already exist.
- This ADR does not require a PostgreSQL UUIDv7 extension or function for Gate‑1. Application-side generation is an accepted implementation for now.

Observed staging evidence (non-normative, test-specific)
- Format/Version: Generated IDs were confirmed to use UUID version 7.
- Primary-key use: UUIDv7 values were successfully stored in Postgres `uuid` PK columns.
- Ordering: Generated UUIDv7 values were time-ordered in staging tests.
- Index locality: A staging benchmark comparing 100,000 UUIDv7 rows to 100,000 UUIDv4 rows observed a smaller B-tree index size for UUIDv7 (3,104 KB vs 4,432 KB in this test). This is an observed staging result and should not be generalized as a fixed production improvement number.
- Replication: Not tested in Gate‑1 (deferred).
- RLS & Outbox: Tenant isolation and Outbox/Dispatcher behavior were validated and observed to be unaffected by the UUIDv7 format in the executed tests.
- Timestamp extraction from UUIDv7 was not used as a validation method (the generator timestamp and created_at were not synchronized in the test).

Consequences (updated)
- Implement an application-side UUIDv7 generator library (single trusted implementation) used by services that create new aggregate rows and Outbox rows.
- Keep storing IDs as Postgres `uuid` values; migrations and schema definitions continue to use `uuid` columns.
- Update migration templates and operational runbooks to document the application-side generator and the requirement to re-run replication validation once a staging replica is available.
- Preserve support for legacy UUIDv4 values in read/compatibility paths.

Alternatives
- DB-side UUIDv7 generation (preferred if and when Supabase/Postgres environment provides a supported extension) — remains an option for future ADR if a DB-native generator becomes available and is validated for replication behavior.
- UUIDv4: random UUIDs (no ordering) — fallback only if UUIDv7 usage proves infeasible in future tests.

Rollback strategy
- If future replication or operational validation reveals issues with UUIDv7, pause production adoption and use UUIDv4 for new records until the issue is resolved.
