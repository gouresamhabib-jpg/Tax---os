# Production Readiness Checklist

A minimal checklist before toggling production traffic for TaxOS. Each item must be verified and signed off by the responsible owner.

Security
- [ ] MFA required for admin accounts
- [ ] SSO configured
- [ ] Secrets in AWS Secrets Manager; rotation policy defined
- [ ] Field-level encryption for PII implemented per policy

Multi-Tenancy & Data Safety
- [ ] RLS policies applied and validated for all tenant-aware tables
- [ ] Dedicated DB option documented for Enterprise
- [ ] Data residency and region-routing tested

Backups & DR
- [ ] PITR enabled
- [ ] Nightly backups verified and restore test performed
- [ ] DR runbook tested

Observability
- [ ] OpenTelemetry traces propagated end-to-end
- [ ] Dashboards in Grafana/CloudWatch for key metrics
- [ ] Alerts for critical failures configured

Eventing
- [ ] Outbox-dispatcher operational in staging
- [ ] NATS JetStream cluster healthy and tested for replay

API
- [ ] OpenAPI validated
- [ ] Rate limiting and WAF rules configured
- [ ] Request/Correlation ID propagation validated

Secrets & Keys
- [ ] KMS Key policy defined
- [ ] Access audit logs active

CI/CD
- [ ] OpenAPI validation in CI
- [ ] RLS policy validation in CI
- [ ] Migration validation in CI

Billing & Usage
- [ ] Usage metering enabled for key metrics (API calls, OCR pages, AI tokens)
- [ ] Billing worker tested in staging

Documentation
- [ ] Runbooks present (dispatch, connectors, DR, incident)
- [ ] ADRs and architecture documents in repo

Sign-off:
- Security Lead: ___________
- Platform Lead: ___________
- Product Owner: ___________
