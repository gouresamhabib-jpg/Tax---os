# ADR-0005: Secrets Management — AWS Secrets Manager + AWS KMS

Status: Accepted

Date: 2026-08-08

Context
- TaxOS requires secure, audited, and scalable secret management for connector credentials, API keys, encryption keys (KEKs), and service accounts.
- Operational overhead should be minimized for initial production while meeting enterprise-grade security, key rotation, and auditing needs.

Decision
- Use AWS Secrets Manager for secrets storage and AWS KMS for key management (CMKs), with customer-managed keys for Enterprise tenants as required.

Rationale
- Managed offering reduces operational burden compared to self-hosted Vault in early phases.
- Native KMS integration for envelope encryption and key policies.
- Built-in rotation, access control via IAM, and audit logs via CloudTrail.
- Good integration with AWS-hosted components and cross-account key management for enterprise isolation.

Consequences
- Store secret metadata (reference path/ARN) in Postgres; do NOT store secret values in DB.
- Use envelope encryption: KEK (master key) in KMS, DEKs generated per tenant and stored encrypted in Secrets Manager or KMS as needed.
- Workers/Edge functions access secrets via short-lived credentials (IAM roles / STS) with least privilege.
- Implement secret access auditing via CloudTrail and send security events to SIEM.

Operational notes
- Define a strict policy for who/what can read secrets (connector workers, dispatcher, ops personnel).
- Implement automated rotation for connector secrets as appropriate.

Alternatives
- HashiCorp Vault: viable if on-prem or multi-cloud requirements later; retain as a future ADR if operational needs favor Vault.
