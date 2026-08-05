# TaxOS — Security Policy

**Document ID:** DOC-08  
**Version:** 1.0  
**Last updated:** July 2026  
**Status:** Active  
**Audience:** All team members, security reviewers, compliance

---

## 1. Overview

TaxOS handles **highly sensitive financial and personal data** — Social Security numbers, income records, tax returns, bank-related documents, and identity information. Security is a foundational product requirement, not a feature. This document defines the security architecture, policies, and procedures for the TaxOS platform.

---

## 2. Security principles

| Principle | Implementation |
|-----------|---------------|
| **Defense in depth** | Multiple security layers — no single point of failure |
| **Least privilege** | Users and services access only what they need |
| **Zero trust** | Verify every request; trust no client input |
| **Encryption everywhere** | Data encrypted in transit and at rest |
| **Secure by default** | RLS enabled, HTTPS enforced, secrets managed |
| **Transparency** | Clear privacy policy; users control their data |
| **Incident readiness** | Documented response plan; regular drills |

---

## 3. Data classification

| Classification | Examples | Handling |
|----------------|----------|----------|
| **Critical** | SSN, TIN, bank account numbers, full tax returns | Encrypted at rest; masked in UI; audit logged; access restricted |
| **Sensitive** | Income amounts, expense details, invoice data, addresses | Encrypted at rest; RLS protected; access logged |
| **Internal** | Subscription status, app settings, notification preferences | RLS protected; standard storage |
| **Public** | App version, feature flags, tax deadline dates | No special handling |

---

## 4. Authentication security

### 4.1 Password policy

| Rule | Requirement |
|------|-------------|
| Minimum length | 8 characters |
| Complexity | Uppercase, lowercase, and number required |
| Common passwords | Blocked (Supabase built-in check) |
| Hashing | bcrypt (Supabase Auth default) |
| Password reset | Email link expires in 1 hour; single use |

### 4.2 Session security

| Control | Implementation |
|---------|---------------|
| Token type | JWT (HS256) |
| Access token expiry | 1 hour |
| Refresh token | Automatic rotation via SDK |
| Session storage | Flutter Secure Storage (Keychain/Keystore) |
| Inactivity timeout | 30 days (app-enforced) |
| Concurrent sessions | Allowed (multi-device) |
| Session invalidation | On password change, account deletion |

### 4.3 OAuth security

| Provider | Controls |
|----------|----------|
| Google | OAuth 2.0 with PKCE; verified redirect URIs |
| Apple | Sign in with Apple; nonce validation |

---

## 5. Authorization

### 5.1 Row Level Security (RLS)

| Rule | Detail |
|------|--------|
| Coverage | 100% of user-facing tables |
| Default | Deny all; explicit policies grant access |
| Pattern | `user_id = auth.uid()` for user-owned data |
| Testing | Automated RLS tests in CI pipeline |
| Bypass | Service role key only in Edge Functions (server-side) |

### 5.2 API authorization

| Layer | Mechanism |
|-------|-----------|
| Client → Supabase | Anon key + user JWT |
| Edge Functions | JWT verification from Authorization header |
| Webhooks | Signature verification (RevenueCat, Stripe) |
| Admin operations | Service role key (CI/CD and Edge Functions only) |

### 5.3 Feature gating

Subscription-based feature access is enforced at two levels:

1. **Client-side** — UI hides/disabled gated features; shows upsell
2. **Server-side** — RPC functions and Edge Functions validate subscription status before processing

Client-side gating is for UX only — server-side gating is the security boundary.

---

## 6. Data protection

### 6.1 Encryption

| State | Method | Standard |
|-------|--------|----------|
| In transit | TLS 1.2+ | All API, storage, and auth communication |
| At rest (database) | AES-256 | Supabase managed (AWS/GCP infrastructure) |
| At rest (storage) | AES-256 | Supabase Storage encryption |
| At rest (device) | Keychain (iOS) / Keystore (Android) | Session tokens and cached credentials |
| Sensitive columns | Application-level encryption | SSN/TIN stored as encrypted references |

### 6.2 Data masking

| Field | Display | Storage |
|-------|---------|---------|
| SSN | `***-**-1234` (last 4 only) | Encrypted full value |
| TIN/EIN | `**-***1234` (last 4 only) | Encrypted full value |
| Bank account | `****1234` (last 4 only) | Not stored in v1 |
| Email | Full (user's own data) | Plain text |
| Phone | `(***) ***-1234` in lists | Plain text |

### 6.3 Data retention

| Data | Retention | Deletion |
|------|-----------|----------|
| Active account data | Indefinite while account active | User-initiated deletion |
| Soft-deleted records | 90 days | Automated purge (Edge Function cron) |
| Auth sessions | 30 days inactivity | Auto-expire |
| Audit logs | 2 years | Automated archive |
| Backups | 30 days | Supabase managed rotation |
| Account deletion | 30-day grace period | Hard delete all user data after grace period |

---

## 7. Application security

### 7.1 Client-side security

| Control | Implementation |
|---------|---------------|
| Certificate pinning | Planned for v1.1 (Supabase TLS cert) |
| Root/jailbreak detection | Warn user; restrict sensitive operations |
| Code obfuscation | Flutter obfuscation enabled in release builds |
| Debug mode | Disabled in production builds |
| API keys | Anon key only (safe with RLS); no service role key |
| Local cache | Encrypted Hive boxes for offline data |
| Clipboard | Auto-clear after 60 seconds for sensitive fields |

### 7.2 Input validation

| Layer | Validation |
|-------|-----------|
| Presentation | Format validation (email, phone, currency, date) |
| Domain | Business rule validation (amount > 0, valid filing status) |
| Database | CHECK constraints, NOT NULL, foreign keys |
| Edge Functions | Request schema validation before processing |

### 7.3 File upload security

| Control | Detail |
|---------|--------|
| MIME type validation | Client and server-side |
| File size limit | 25 MB documents, 10 MB receipts |
| Virus scanning | Planned for v1.1 (ClamAV Edge Function) |
| Storage path | User-scoped paths prevent cross-user access |
| Execution prevention | Storage serves files only — no script execution |

---

## 8. Infrastructure security

### 8.1 Supabase security

| Control | Status |
|---------|--------|
| RLS enabled | Required on all tables |
| SSL enforcement | Enabled |
| Network restrictions | Configured for production (IP allowlist for admin) |
| Database password | Rotated quarterly |
| Service role key | Stored in CI secrets only |
| Dashboard access | MFA required; limited to authorized team members |

### 8.2 CI/CD security

| Control | Implementation |
|---------|---------------|
| Secrets management | GitHub Actions secrets (encrypted) |
| Branch protection | `main` requires PR review + CI pass |
| Dependency scanning | Dependabot enabled |
| SAST | Static analysis in CI pipeline |
| Environment isolation | Separate Supabase projects per environment |

---

## 9. Privacy and compliance

### 9.1 Regulatory alignment

| Regulation | Status | Key requirements |
|------------|--------|-----------------|
| **GDPR** | Ready | Data export, deletion, consent, privacy policy |
| **CCPA** | Ready | Do not sell; deletion rights; privacy policy |
| **SOC 2 Type II** | Planned (Year 2) | Access controls, audit logging, encryption |
| **IRS Publication 1075** | Planned (e-file phase) | Federal tax information safeguards |
| **PCI DSS** | N/A (v1) | No direct payment card handling (IAP only) |

### 9.2 User privacy rights

| Right | Implementation |
|-------|---------------|
| Access | Users view all their data in the app |
| Export | Data export feature (JSON/CSV) |
| Deletion | Account deletion with 30-day grace period |
| Correction | Users edit their profile and tax data |
| Consent | Explicit consent during onboarding |
| Do not sell | TaxOS never sells user data |

### 9.3 Privacy policy requirements

The privacy policy (hosted externally, linked in app) must cover:

- What data is collected and why
- How data is stored and protected
- Third-party services used (Supabase, Sentry, analytics)
- User rights and how to exercise them
- Data retention periods
- Contact information for privacy inquiries

---

## 10. Incident response

### 10.1 Severity levels

| Level | Description | Response time | Example |
|-------|-------------|---------------|---------|
| **P0 — Critical** | Active data breach or exposure | 1 hour | Database exposed without RLS |
| **P1 — High** | Vulnerability with exploit potential | 4 hours | Auth bypass discovered |
| **P2 — Medium** | Vulnerability without known exploit | 24 hours | Information disclosure in logs |
| **P3 — Low** | Minor security improvement | 1 week | Missing security header |

### 10.2 Response procedure

| Step | Action | Owner |
|------|--------|-------|
| 1. Detect | Alert via monitoring, user report, or audit | On-call engineer |
| 2. Triage | Assess severity and scope | Security lead |
| 3. Contain | Isolate affected systems; revoke compromised keys | Engineering |
| 4. Investigate | Determine root cause and data impact | Security + Engineering |
| 5. Remediate | Fix vulnerability; deploy patch | Engineering |
| 6. Notify | Inform affected users per legal requirements | Legal + Product |
| 7. Review | Post-incident review; update procedures | All stakeholders |

### 10.3 Breach notification

| Jurisdiction | Requirement | Timeline |
|--------------|-------------|----------|
| GDPR | Notify supervisory authority | 72 hours |
| GDPR | Notify affected users | Without undue delay |
| CCPA | Notify affected California residents | Without unreasonable delay |
| General | Email notification to affected users | As soon as confirmed |

---

## 11. Vulnerability management

### 11.1 Reporting

| Channel | Detail |
|---------|--------|
| Email | security@taxos.com |
| Response SLA | Acknowledge within 48 hours |
| Assessment SLA | Initial assessment within 5 business days |
| Public disclosure | Coordinated with reporter; credit given |

### 11.2 Internal security practices

| Practice | Frequency |
|----------|-----------|
| Dependency updates | Weekly (Dependabot) |
| Security audit | Before each major release |
| Penetration testing | Annually (starting Year 2) |
| RLS policy review | Each migration PR |
| Access review | Quarterly |
| Key rotation | Quarterly (service role key) |
| Security training | Onboarding + annual refresher |

---

## 12. Third-party security

| Service | Data shared | Security assessment |
|---------|-------------|-------------------|
| Supabase | All application data | SOC 2 Type II certified |
| Apple/Google (IAP) | Subscription events | Platform-managed |
| RevenueCat | Subscription status | SOC 2 certified |
| Sentry | Error logs (no PII) | SOC 2 certified |
| PostHog | Analytics events (anonymized) | SOC 2 certified |
| Firebase (FCM) | Push notification tokens | Google Cloud security |

**Rule:** New third-party integrations require security review before integration.

---

## 13. Security checklist for releases

- [ ] All tables have RLS policies enabled and tested
- [ ] No secrets in source code or client bundle
- [ ] Service role key used only in server-side code
- [ ] Input validation on all user-facing forms
- [ ] Sensitive fields masked in UI
- [ ] Error messages do not leak internal details
- [ ] Dependencies scanned for known vulnerabilities
- [ ] Release build has obfuscation enabled
- [ ] Debug logging disabled in production
- [ ] Privacy policy and terms accessible in app
- [ ] Account deletion flow tested end-to-end

---

## 14. Contact

| Role | Contact |
|------|---------|
| Security reports | security@taxos.com |
| Privacy inquiries | privacy@taxos.com |
| Legal | legal@taxos.com |
| Data protection officer | dpo@taxos.com (when appointed) |

---

**Related documents:** [04_DATABASE.md](04_DATABASE.md) · [07_SUPABASE_GUIDE.md](07_SUPABASE_GUIDE.md) · [00_PROJECT_RULES.md](00_PROJECT_RULES.md) · Root [SECURITY.md](../SECURITY.md)
