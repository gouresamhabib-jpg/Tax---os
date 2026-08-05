# TaxOS — Product Vision

**Document ID:** DOC-01  
**Version:** 1.0  
**Last updated:** July 2026  
**Status:** Active  
**Audience:** Leadership, product, engineering, design, investors

---

## 1. Vision statement

**TaxOS makes tax compliance effortless, accurate, and accessible for everyone — turning a source of anxiety into a source of confidence.**

We believe that managing taxes should not require a accounting degree, expensive software, or weeks of stress. TaxOS delivers a mobile-first experience that guides users through their entire tax lifecycle — from daily expense capture to final filing — with intelligence, security, and clarity.

---

## 2. Mission

To build the most trusted, user-friendly tax management platform that empowers individuals, freelancers, and small businesses to stay compliant, maximize legitimate deductions, and file with confidence — while giving accounting professionals the tools to serve clients at scale.

---

## 3. The problem

### 3.1 For individuals and freelancers

- Tax preparation is **confusing** — rules change yearly, forms are opaque, deadlines are easy to miss
- Expense tracking is **fragmented** — receipts live in email, photos, and spreadsheets
- Existing tools are **desktop-centric** — built for accountants, not mobile-first users
- Errors are **costly** — mistakes lead to penalties, audits, and lost deductions
- Trust is **low** — users fear sharing financial data with unknown platforms

### 3.2 For small businesses

- Bookkeeping and tax prep consume **disproportionate time** relative to revenue
- Invoicing, expenses, and tax filing live in **disconnected systems**
- Hiring an accountant is **expensive** for early-stage businesses
- Compliance deadlines across federal, state, and local jurisdictions create **complexity**

### 3.3 For accounting firms

- Client document collection is **manual and repetitive**
- Legacy software has **poor mobile experiences** for client interaction
- Scaling client volume requires **better tooling**, not more headcount

---

## 4. Our solution

TaxOS is a **commercial SaaS platform** that unifies the tax lifecycle in a single mobile application:

| Capability | User benefit |
|------------|--------------|
| Smart onboarding | Personalized tax profile in minutes |
| Expense capture | Snap receipts, auto-categorize, never lose a deduction |
| Document vault | Secure, organized storage for all tax-related documents |
| Tax calculator | Real-time estimates so there are no surprises |
| Guided filing | Step-by-step return preparation with plain-language explanations |
| Invoicing | Send invoices and track payments (freelancers and SMBs) |
| Client management | Firms manage multiple clients from one dashboard (future) |
| Reports & exports | PDF/CSV reports for personal records or accountant handoff |
| Subscription billing | Transparent pricing with no hidden fees |

Powered by **Flutter** for a premium cross-platform experience and **Supabase** for secure, scalable backend infrastructure.

---

## 5. Target audience

### 5.1 Primary personas

**Alex — The Freelancer**
- Age 28–45, independent contractor or gig worker
- Multiple income streams, many deductible expenses
- Uses phone for everything; wants simplicity and speed
- Willing to pay $15–30/month for peace of mind

**Jordan — The Small Business Owner**
- Age 35–55, LLC or S-Corp with 1–10 employees
- Needs invoicing, expense tracking, and quarterly estimates
- Values accuracy over lowest price
- Willing to pay $30–75/month

**Sam — The Individual Filer**
- Age 22–65, W-2 employee with moderate complexity
- Filed with TurboTax or H&R Block but wants a better mobile experience
- Price-sensitive; likely on a free or low-tier plan
- Converts to paid during filing season

### 5.2 Secondary personas (future phases)

**Taylor — The Tax Professional**
- CPA or enrolled agent managing 50–500 clients
- Needs client portals, bulk document intake, and review workflows
- Enterprise pricing tier

---

## 6. Value propositions

| Stakeholder | Core value |
|-------------|------------|
| End users | "File taxes from your phone in half the time, with zero guesswork." |
| Freelancers | "Never miss a deduction — capture expenses as they happen." |
| Small businesses | "One app for invoicing, expenses, and tax compliance." |
| Accounting firms | "Collect client documents effortlessly and scale your practice." (future) |
| Investors | "Large addressable market, recurring revenue, mobile-first differentiation." |

---

## 7. Differentiation

| Dimension | TaxOS | Traditional desktop tools | Spreadsheet DIY |
|-----------|-------|--------------------------|-----------------|
| Mobile-first | Native Flutter app | Afterthought mobile apps | Not mobile |
| Real-time estimates | Built-in calculator | Limited | Manual |
| Expense capture | Camera + auto-categorize | Manual entry | Manual |
| Guided experience | Step-by-step wizard | Form-heavy | None |
| Pricing | Transparent subscription | Opaque upsells | Free but risky |
| Security | Supabase RLS, encryption | Varies | None |
| Speed to file | Optimized flow | Slow, bloated | Hours of research |

---

## 8. Strategic pillars

### Pillar 1 — Trust and security
Tax data is among the most sensitive information a person owns. TaxOS treats security as a feature, not an afterthought. SOC 2 readiness, encryption, RLS, and transparent privacy policies are foundational.

### Pillar 2 — Mobile excellence
The primary interaction surface is a phone. Every screen, flow, and interaction is designed for thumb-first navigation, offline resilience, and fast performance.

### Pillar 3 — Intelligent guidance
TaxOS does not dump forms on users. It asks the right questions, explains implications in plain language, and surfaces relevant deductions proactively.

### Pillar 4 — Ecosystem integration
Future integrations with banks, payroll providers, and government e-file systems expand the platform's value without requiring manual data entry.

### Pillar 5 — Sustainable business model
Subscription revenue funds ongoing development, tax law updates, and customer support. Free tiers drive acquisition; premium tiers drive revenue.

---

## 9. Success metrics

### 9.1 North star metric

**Completed tax filings per active user per season** — measures end-to-end value delivery.

### 9.2 Supporting metrics

| Category | Metric | Target (Year 1) |
|----------|--------|-----------------|
| Acquisition | Monthly sign-ups | 10,000 |
| Activation | Onboarding completion rate | > 70% |
| Engagement | Weekly active users (peak season) | 40% of registered |
| Revenue | Monthly recurring revenue (MRR) | $150K by month 12 |
| Retention | Annual renewal rate | > 60% |
| Quality | Filing error rate | < 0.5% |
| Satisfaction | App Store rating | > 4.5 |
| Support | Average resolution time | < 4 hours |

---

## 10. Brand principles

| Principle | Expression |
|-----------|------------|
| **Clarity** | Plain language, no jargon unless explained |
| **Confidence** | Users feel in control, not overwhelmed |
| **Calm** | Visual design reduces anxiety — soft colors, generous spacing |
| **Competence** | Accurate calculations, reliable data, professional polish |
| **Transparency** | Pricing, data usage, and tax logic are visible and honest |

---

## 11. Long-term vision (3–5 years)

1. **Year 1** — US individual and freelancer mobile app with core filing workflow
2. **Year 2** — Small business features, accountant portal, state e-file partnerships
3. **Year 3** — IRS e-file certification, bank/payroll integrations, AI-assisted deduction discovery
4. **Year 4** — Multi-state optimization, international expansion (Canada, UK)
5. **Year 5** — Full accounting firm platform with white-label options

---

## 12. What we will not do

- Sell user tax data to third parties
- Provide tax advice without appropriate disclaimers and professional referrals
- Ship features that compromise security for speed
- Target enterprise before product-market fit with SMB/individual segments
- Expand to new countries before dominating the US market

---

## 13. Guiding questions for every decision

Before building any feature, ask:

1. Does this help users file accurately and on time?
2. Does this work beautifully on a phone?
3. Does this build trust or erode it?
4. Can we ship this without compromising security?
5. Does this align with our subscription business model?

If any answer is "no," reconsider or defer.

---

**Related documents:** [02_PRD.md](02_PRD.md) · [09_ROADMAP.md](09_ROADMAP.md) · [05_UI_GUIDELINES.md](05_UI_GUIDELINES.md)
