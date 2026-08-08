# ADR-0003: Event Bus Selection — NATS JetStream

Status: Accepted

Date: 2026-08-08

Authors: Chief Software Architect

Context
- TaxOS is event-driven and requires a durable, scalable message streaming system to support high-throughput publish/subscribe patterns, stream replay, durable consumers, and low-latency processing by independent workers (OCR, Connectors, Indexer, Scheduler, Billing, AI pipeline).
- We will use an Outbox pattern in Postgres to guarantee transactional publishing from aggregate state changes. The Outbox will be consumed by a dispatcher that publishes to the Event Bus.

Decision
- Use NATS JetStream as the primary Event Bus for TaxOS.

Rationale
- Performance: NATS provides low-latency messaging suitable for high-throughput scenarios.
- JetStream features: durable streams, message persistence, stream replay, at-least-once delivery with acknowledgement semantics, and consumer groups (durable consumers) — fits our Outbox + Dispatcher design.
- Operational simplicity: smaller operational overhead than RabbitMQ for streaming workloads at scale; mature client libraries across languages.
- Scalability: JetStream supports clustered deployments and horizontal scale.

Consequences
- Implement dispatcher that publishes Outbox records to JetStream subjects.
- Consumers (workers) subscribe to subjects and implement idempotent handlers.
- Use JetStream features for replay and DLQ.
- Document operational runbooks for JetStream cluster management.

Alternatives Considered
- RabbitMQ: richer routing features and plugins; higher operational complexity for wide streaming+replay workloads. Could be considered later if broker requirements change.

Migration & Operational Notes
- Provide monitoring dashboards (Prometheus metrics exporter for NATS), backup strategy for streams, and scaling plan.
