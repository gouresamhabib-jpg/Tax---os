# TaxOS — Project Rules

**Document ID:** DOC-00  
**Version:** 1.0  
**Last updated:** July 2026  
**Status:** Active  
**Audience:** All contributors, contractors, and AI agents working on TaxOS

---

## 1. Purpose

This document defines the non-negotiable rules that govern how TaxOS is built, maintained, and shipped. Every decision — technical, product, or operational — must align with these rules. When in doubt, escalate to the project lead before proceeding.

---

## 2. Product identity

| Attribute | Value |
|-----------|-------|
| Product name | TaxOS |
| Category | Commercial SaaS — tax management, filing, and compliance |
| Primary platform | Flutter (mobile-first) |
| Backend | Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions) |
| License | Proprietary — see root `LICENSE` |
| Target markets | Individuals, freelancers, small businesses, and accounting firms |

TaxOS is **not** open source. All source code, documentation, and infrastructure configurations are confidential unless explicitly approved for external release.

---

## 3. Architectural mandates

### 3.1 Feature-first organization

All application logic lives under `lib/features/<feature_name>/`. No feature may depend on another feature's internal implementation — only on published domain contracts or shared abstractions in `lib/shared/` and `lib/core/`.

### 3.2 Clean Architecture layers

Every feature must implement three layers:

| Layer | Responsibility | Allowed dependencies |
|-------|----------------|----------------------|
| **Presentation** | UI, state management, user input | Domain only |
| **Domain** | Business rules, entities, use case contracts | None (pure Dart) |
| **Data** | API calls, DTOs, repository implementations | Domain, Supabase SDK |

**Dependency rule:** dependencies always point inward. Presentation → Domain ← Data.

### 3.3 No business logic in UI

Widgets, pages, and BLoC/Cubit classes must not contain tax calculations, validation rules, or persistence logic. These belong in domain use cases.

### 3.4 No Supabase in domain or presentation

The Supabase client, SQL, and RLS policy logic must never be imported in `domain/` or `presentation/` layers. All backend access goes through repository interfaces defined in domain and implemented in data.

---

## 4. Repository structure rules

| Path | Rule |
|------|------|
| `apps/mobile/` | Flutter shell only — platform targets, `pubspec.yaml`, thin entry point |
| `lib/` | All application source code |
| `assets/` | Static assets referenced from pubspec; no logic |
| `database/` | All Supabase SQL migrations, RLS policies, seeds, and edge functions |
| `docs/` | Authoritative documentation — code comments do not replace docs |
| `scripts/` | Automation only — no business logic |
| `.github/` | CI/CD, issue templates, PR templates |
| `.cursor/` | Cursor IDE rules and agent skills |

**Do not** create parallel folder structures or duplicate features outside `lib/features/`.

---

## 5. Development workflow rules

### 5.1 Branching

- `main` — always deployable; protected branch
- `develop` — integration branch (optional, team decision)
- Feature branches: `feature/<ticket>-<short-description>`
- Fix branches: `fix/<ticket>-<short-description>`

### 5.2 Pull requests

- One feature or fix per PR
- PR must pass CI (lint, test, build) before merge
- At least one approved review required
- Squash merge to `main`
- PR description must reference related issue/ticket

### 5.3 Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(tax-filing): add quarterly estimate wizard
fix(auth): resolve session refresh race condition
docs(architecture): update layer dependency diagram
chore(deps): bump supabase_flutter to 2.x
```

### 5.4 Database changes

- Every schema change requires a migration file in `database/migrations/`
- Migrations are immutable once merged to `main`
- RLS policies must be defined before any table goes to production
- Never apply manual SQL directly to production without a migration

---

## 6. Security rules

1. **Never commit secrets** — API keys, service role keys, `.env` files, certificates
2. **Service role key** is server-side only (Edge Functions, CI secrets) — never in the mobile app
3. **Row Level Security (RLS)** must be enabled on every user-facing table
4. **PII and tax data** must be encrypted at rest (Supabase default) and in transit (TLS)
5. Security vulnerabilities are reported per `docs/08_SECURITY.md` — never via public issues

---

## 7. Quality gates

| Gate | Requirement |
|------|-------------|
| Lint | Zero warnings on changed files (`flutter analyze`) |
| Unit tests | Domain use cases and repositories must have tests |
| Widget tests | Critical user flows (auth, filing submission) must have tests |
| Documentation | New features update relevant docs in `docs/` |
| Accessibility | WCAG 2.1 AA for all user-facing screens |
| Localization | All user-visible strings externalized from day one |

---

## 8. Scope control

### 8.1 In scope (v1)

- Mobile app (iOS and Android)
- Individual and freelancer tax workflows
- Document upload and categorization
- Tax filing preparation and status tracking
- Subscription billing
- Supabase backend

### 8.2 Out of scope (v1)

- Web admin portal (planned v2)
- Desktop application
- Direct IRS e-file integration (requires certification — planned later phase)
- Multi-country tax support (US-first for v1)

Changes to scope require product lead approval and an update to `docs/02_PRD.md` and `docs/09_ROADMAP.md`.

---

## 9. Documentation rules

1. `docs/` is the single source of truth for architecture, product, and process
2. Numbered documents (`00_` through `12_`) are authoritative and versioned
3. When code and docs conflict, **docs win until code is fixed**
4. Architecture Decision Records (ADRs) live in `docs/adr/` for significant technical choices
5. Every new feature must have an entry in `docs/12_BACKLOG.md` before development starts

---

## 10. AI agent rules (Cursor)

Agents working on TaxOS must:

1. Read `docs/00_PROJECT_RULES.md` and `docs/11_CURSOR_RULES.md` before making changes
2. Follow Clean Architecture — never shortcut layers
3. Not generate application code unless explicitly requested
4. Not modify `LICENSE`, security policies, or RLS without human review
5. Propose changes via PR-sized diffs — no sweeping refactors without approval

---

## 11. Communication and escalation

| Situation | Action |
|-----------|--------|
| Architectural uncertainty | Consult `docs/03_ARCHITECTURE.md`, then tech lead |
| Product ambiguity | Consult `docs/02_PRD.md`, then product owner |
| Security concern | Stop work, follow `docs/08_SECURITY.md` |
| Scope creep | Document in backlog, escalate to product owner |
| Breaking change | Write ADR, notify team, update CHANGELOG |

---

## 12. Document maintenance

| Trigger | Action |
|---------|--------|
| New major feature | Update PRD, roadmap, backlog, architecture if needed |
| Schema change | Update `docs/04_DATABASE.md` |
| UI pattern change | Update `docs/05_UI_GUIDELINES.md` |
| New coding convention | Update `docs/10_CODING_STANDARD.md` |
| Quarterly review | Review all numbered docs for accuracy |

---

## 13. Acknowledgment

By contributing to TaxOS, you agree to follow these project rules. Violations that reach production may result in revert, incident review, and process updates to prevent recurrence.

**Related documents:** [01_PRODUCT_VISION.md](01_PRODUCT_VISION.md) · [03_ARCHITECTURE.md](03_ARCHITECTURE.md) · [10_CODING_STANDARD.md](10_CODING_STANDARD.md) · [11_CURSOR_RULES.md](11_CURSOR_RULES.md)
