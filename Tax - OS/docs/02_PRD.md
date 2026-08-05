# TaxOS — Product Requirements Document (PRD)

**Document ID:** DOC-02  
**Version:** 1.0  
**Last updated:** July 2026  
**Status:** Active  
**Owner:** Product  
**Audience:** Product, engineering, design, QA

---

## 1. Overview

### 1.1 Document purpose

This PRD defines the functional and non-functional requirements for TaxOS v1.0 — the initial commercial release targeting US-based individuals and freelancers on iOS and Android.

### 1.2 Product summary

TaxOS is a mobile SaaS application that enables users to track expenses, manage tax documents, estimate tax liability, and prepare tax returns through a guided, step-by-step workflow.

### 1.3 Release scope

| In scope (v1.0) | Out of scope (v1.0) |
|-----------------|---------------------|
| iOS and Android mobile app | Web application |
| US federal individual return (1040) | Business entity returns (1120, 1065) |
| Expense tracking and categorization | Direct IRS e-file submission |
| Document upload and storage | Multi-country support |
| Tax estimation calculator | Accountant firm portal |
| Subscription billing (Free, Pro, Premium) | Bank account linking |
| Push notifications | Live chat support |
| User profile and settings | AI-powered audit defense |

---

## 2. User personas (v1 focus)

Refer to [01_PRODUCT_VISION.md](01_PRODUCT_VISION.md) for full persona profiles. v1.0 prioritizes **Alex (Freelancer)** and **Sam (Individual Filer)**.

---

## 3. User stories and requirements

### 3.1 Authentication and account management

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| AUTH-01 | As a new user, I want to sign up with email and password so I can create an account | P0 | Email validation, password strength rules (8+ chars, mixed case, number), confirmation email sent |
| AUTH-02 | As a user, I want to sign in with email and password | P0 | Successful login returns session; invalid credentials show clear error |
| AUTH-03 | As a user, I want to sign in with Google/Apple | P1 | OAuth flow completes; account linked or created |
| AUTH-04 | As a user, I want to reset my password | P0 | Reset email sent; link expires in 1 hour; new password meets strength rules |
| AUTH-05 | As a user, I want to sign out | P0 | Session cleared; redirected to login |
| AUTH-06 | As a user, I want my session to persist securely | P0 | Token refresh handled automatically; session expires after 30 days inactivity |
| AUTH-07 | As a user, I want to delete my account | P1 | Confirmation required; all user data deleted within 30 days per privacy policy |

### 3.2 Onboarding

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| ONB-01 | As a new user, I want a guided onboarding wizard | P0 | 5-step wizard: welcome, tax profile, filing status, income types, completion |
| ONB-02 | As a user, I want to specify my filing status | P0 | Options: Single, MFJ, MFS, HOH, Qualifying Widow |
| ONB-03 | As a user, I want to indicate my income types | P0 | Multi-select: W-2, 1099, self-employment, investments, rental, other |
| ONB-04 | As a user, I want to skip onboarding and complete later | P1 | Dashboard accessible with "Complete profile" banner |
| ONB-05 | As a user, I want to set my tax year | P0 | Defaults to current tax year; user can select prior year for amendments |

### 3.3 Dashboard

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| DASH-01 | As a user, I want a home dashboard showing my tax overview | P0 | Displays: estimated liability/refund, filing status, upcoming deadlines, recent activity |
| DASH-02 | As a user, I want quick actions on the dashboard | P0 | Shortcuts: Add expense, Upload document, Start filing, View reports |
| DASH-03 | As a user, I want to see my filing progress | P0 | Progress bar showing completion percentage for active return |
| DASH-04 | As a user, I want deadline reminders visible | P1 | Countdown to next relevant deadline (quarterly estimate, filing date) |

### 3.4 Expense tracking

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| EXP-01 | As a user, I want to manually add an expense | P0 | Fields: amount, date, category, description, receipt (optional) |
| EXP-02 | As a user, I want to photograph a receipt | P0 | Camera capture or gallery pick; image stored in Supabase Storage |
| EXP-03 | As a user, I want expenses auto-categorized | P1 | Suggested category based on description/merchant; user can override |
| EXP-04 | As a user, I want to view expenses by category and date range | P0 | Filterable list with category totals |
| EXP-05 | As a user, I want to edit and delete expenses | P0 | Full CRUD with confirmation on delete |
| EXP-06 | As a user, I want to mark expenses as business/personal | P0 | Toggle affects deduction calculations |
| EXP-07 | As a user, I want to export expenses | P2 | CSV export for date range |

### 3.5 Document management

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| DOC-01 | As a user, I want to upload tax documents | P0 | Supports PDF, JPG, PNG; max 25 MB per file |
| DOC-02 | As a user, I want documents organized by type | P0 | Categories: W-2, 1099, receipt, invoice, prior return, other |
| DOC-03 | As a user, I want to view and preview documents | P0 | In-app preview for images and PDFs |
| DOC-04 | As a user, I want to tag and search documents | P1 | Full-text search on filename and tags |
| DOC-05 | As a user, I want documents linked to my tax return | P1 | Documents attachable to specific return line items |

### 3.6 Tax calculator

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| CALC-01 | As a user, I want a real-time tax estimate | P0 | Updates as income, deductions, and credits change |
| CALC-02 | As a user, I want to see federal and state estimates separately | P1 | State support for top 10 states in v1 |
| CALC-03 | As a user, I want to run what-if scenarios | P2 | Adjust income/deductions and see impact without saving |
| CALC-04 | As a user, I want plain-language explanations of my estimate | P0 | Breakdown showing taxable income, effective rate, marginal rate |

### 3.7 Tax filing

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| FILE-01 | As a user, I want to start a new tax return | P0 | Creates return for selected tax year; pre-fills from profile |
| FILE-02 | As a user, I want a step-by-step filing wizard | P0 | Sections: Personal info, Income, Deductions, Credits, Review, Submit |
| FILE-03 | As a user, I want income entry forms matching IRS schedules | P0 | W-2 entry, 1099 entry, Schedule C for self-employment |
| FILE-04 | As a user, I want guided deduction selection | P0 | Standard vs. itemized comparison; common deductions checklist |
| FILE-05 | As a user, I want a review page before submission | P0 | Summary of all entries with edit links; tax calculation final |
| FILE-06 | As a user, I want to save progress and resume later | P0 | Return state persisted; resume from last completed section |
| FILE-07 | As a user, I want to export my completed return as PDF | P0 | Generated PDF matching IRS form layout |
| FILE-08 | As a user, I want filing status tracking | P1 | Statuses: Draft, Ready, Submitted (manual), Accepted, Rejected |

### 3.8 Invoicing (Freelancer tier)

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| INV-01 | As a freelancer, I want to create and send invoices | P1 | Fields: client, line items, tax, due date; PDF generation |
| INV-02 | As a freelancer, I want to track invoice status | P1 | Statuses: Draft, Sent, Paid, Overdue, Cancelled |
| INV-03 | As a freelancer, I want paid invoices reflected in income | P1 | Paid invoices auto-added to income for tax calculation |

### 3.9 Reports

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| RPT-01 | As a user, I want an annual tax summary report | P1 | PDF with income, deductions, credits, final liability |
| RPT-02 | As a user, I want an expense report by category | P1 | PDF/CSV with category breakdown and totals |
| RPT-03 | As a user, I want a quarterly estimate report | P2 | Estimated quarterly payment amounts |

### 3.10 Subscriptions and billing

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| SUB-01 | As a user, I want to see available plans | P0 | Free, Pro ($19.99/mo), Premium ($39.99/mo) with feature comparison |
| SUB-02 | As a user, I want to subscribe in-app | P0 | Apple/Google IAP for mobile; Stripe for web (future) |
| SUB-03 | As a user, I want to manage my subscription | P0 | View current plan, upgrade, downgrade, cancel |
| SUB-04 | As a free user, I want to hit feature limits gracefully | P0 | Clear upsell when limits reached (e.g., 10 expenses/month on Free) |

**Plan feature matrix:**

| Feature | Free | Pro | Premium |
|---------|------|-----|---------|
| Expense tracking | 10/month | Unlimited | Unlimited |
| Document storage | 100 MB | 5 GB | 25 GB |
| Tax calculator | Basic | Full | Full + scenarios |
| Tax filing | 1 return/year | 3 returns/year | Unlimited |
| Invoicing | — | 10/month | Unlimited |
| Reports | — | Basic | Full |
| Priority support | — | — | Yes |

### 3.11 Notifications

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| NOTIF-01 | As a user, I want push notifications for deadlines | P1 | Configurable; default on for filing deadlines |
| NOTIF-02 | As a user, I want in-app notification center | P1 | List of notifications with read/unread state |
| NOTIF-03 | As a user, I want to control notification preferences | P1 | Toggle by category: deadlines, payments, product updates |

### 3.12 Settings and profile

| ID | User story | Priority | Acceptance criteria |
|----|-----------|----------|---------------------|
| SET-01 | As a user, I want to edit my profile | P0 | Name, email, phone, address |
| SET-02 | As a user, I want to update my tax profile | P0 | Filing status, dependents, income types |
| SET-03 | As a user, I want to change app preferences | P1 | Theme (light/dark/system), language, currency format |
| SET-04 | As a user, I want to view privacy policy and terms | P0 | In-app webview to hosted legal pages |
| SET-05 | As a user, I want to manage connected accounts | P1 | View/unlink OAuth providers |

---

## 4. Non-functional requirements

### 4.1 Performance

| Requirement | Target |
|-------------|--------|
| App cold start | < 3 seconds on mid-range device |
| Screen transition | < 300 ms |
| API response (p95) | < 500 ms |
| Document upload (10 MB) | < 10 seconds on 4G |
| Offline expense entry | Supported; sync on reconnect |

### 4.2 Security

| Requirement | Detail |
|-------------|--------|
| Authentication | Supabase Auth with JWT; refresh token rotation |
| Authorization | RLS on all tables; users access only their data |
| Data encryption | TLS 1.2+ in transit; AES-256 at rest |
| Storage | Private buckets with signed URLs; no public document access |
| Compliance | GDPR-ready data export/deletion; CCPA compliance |

### 4.3 Reliability

| Requirement | Target |
|-------------|--------|
| Uptime | 99.9% (Supabase SLA) |
| Data backup | Daily automated backups with 30-day retention |
| Error rate | < 0.1% of API requests return 5xx |

### 4.4 Accessibility

| Requirement | Standard |
|-------------|----------|
| Screen reader support | VoiceOver (iOS), TalkBack (Android) |
| Color contrast | WCAG 2.1 AA minimum |
| Touch targets | Minimum 44×44 pt |
| Text scaling | Supports system font scaling up to 200% |

### 4.5 Localization

| Requirement | Detail |
|-------------|--------|
| v1 language | English (US) only |
| Architecture | All strings externalized via ARB files for future i18n |
| Currency | USD only in v1 |
| Date format | US format (MM/DD/YYYY) default |

---

## 5. Technical constraints

- Flutter stable channel, Dart 3.x
- Supabase for all backend services
- Minimum OS: iOS 15+, Android API 24+
- No direct IRS API in v1 (manual PDF export)
- State tax: top 10 US states by population

---

## 6. Dependencies and integrations

| Integration | Purpose | Phase |
|-------------|---------|-------|
| Supabase Auth | User authentication | v1.0 |
| Supabase PostgreSQL | Data storage | v1.0 |
| Supabase Storage | Document/receipt storage | v1.0 |
| Supabase Realtime | Live sync (notifications) | v1.0 |
| Apple In-App Purchase | iOS subscriptions | v1.0 |
| Google Play Billing | Android subscriptions | v1.0 |
| RevenueCat | Subscription management abstraction | v1.0 |
| Firebase Cloud Messaging | Push notifications | v1.0 |
| Sentry | Error monitoring | v1.0 |
| PostHog / Mixpanel | Product analytics | v1.0 |

---

## 7. Risks and mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Tax law changes mid-season | High | Medium | Modular tax rule engine; rapid update pipeline |
| IRS e-file certification delay | High | High | v1 exports PDF for manual filing; e-file in v2 |
| Supabase outage | High | Low | Offline mode for expense entry; status page monitoring |
| App Store rejection | Medium | Medium | Pre-submission review; compliance with IAP guidelines |
| Data breach | Critical | Low | RLS, encryption, penetration testing, incident response plan |
| Low conversion free → paid | High | Medium | Optimized upsell flows; filing season promotions |

---

## 8. Success criteria for v1.0 launch

| Criteria | Target |
|----------|--------|
| Core user flow completion | Sign up → onboard → add expenses → file return → export PDF |
| Crash-free rate | > 99.5% |
| App Store approval | iOS and Android |
| Beta user satisfaction | > 4.0/5.0 |
| P0 bugs at launch | Zero |
| Security audit | Passed |

---

## 9. Open questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| 1 | RevenueCat vs. native IAP only? | Product | Pending |
| 2 | Which 10 states for v1 state tax? | Product/Tax | Pending |
| 3 | Free tier expense limit: 10 or 25/month? | Product | Pending |
| 4 | PDF generation: client-side or Edge Function? | Engineering | Pending |
| 5 | Amendment filing in v1 or v1.1? | Product | Deferred to v1.1 |

---

**Related documents:** [01_PRODUCT_VISION.md](01_PRODUCT_VISION.md) · [09_ROADMAP.md](09_ROADMAP.md) · [12_BACKLOG.md](12_BACKLOG.md) · [04_DATABASE.md](04_DATABASE.md)
