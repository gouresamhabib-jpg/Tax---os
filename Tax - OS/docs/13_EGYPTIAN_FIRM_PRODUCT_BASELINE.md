# TaxOS — Egyptian Accounting Firm Product Baseline

**Document ID:** DOC-13  
**Version:** 1.0  
**Status:** Approved product direction; implementation baseline  
**Decision date:** 23 November 2026  
**Owner:** Product

## 1. Product decision

TaxOS is a commercial, multi-tenant SaaS operating system for Egyptian accounting and tax advisory firms. Its primary customer is the accounting office; its daily users are the office owner, managers, accountants, reviewers, and authorized support staff.

TaxOS centralizes the office's work across its client portfolio. It is not a consumer tax-return application, a generic CRM, an e-invoicing product, or a replacement for the Egyptian Tax Authority (ETA) portal.

The initial product is designed for an accounting office managing a substantial portfolio of Egyptian businesses and taxpayers. The platform should help the office know what is due, who owns the work, what evidence is missing, what has been filed or paid, and what the office has learned from prior cases.

## 2. Target users and workspace

### Primary customer
An Egyptian accounting, tax, audit, or advisory office operating as an independent tenant.

### Workspace roles
- **Office owner / tenant administrator:** manages the office, team, access, subscription, and firm-wide settings.
- **Office manager:** allocates work, monitors deadlines, reviews workload, and escalates overdue items.
- **Accountant / tax specialist:** maintains client records, prepares obligations, uploads evidence, and records filing/payment progress.
- **Reviewer / approver:** reviews workpapers, supporting documents, calculations, and submissions before completion.
- **Read-only / client-facing user:** limited access where a client portal is introduced in a later phase.

An office may have multiple employees. A person may belong to an office through an explicit membership and role; the database must not assume that one authenticated user is permanently equivalent to one accounting office.

## 3. Product scope

### Core v1 capabilities
1. **Office workspace and team access** — office profile, employee invitations, membership, roles, and permission boundaries.
2. **Client / taxpayer registry** — legal name, tax registration identifiers, legal form, activity, branches, contacts, assigned accountant, and tax profile.
3. **Tax obligations register** — obligations by client, tax type, period, statutory due date, assigned owner, status, and evidence.
4. **Work management** — tasks, checklists, review/approval steps, dependencies, escalation, and a complete activity timeline.
5. **Documents and evidence** — secure document storage, categorization, client/obligation linking, version history, and missing-document tracking.
6. **Calendar and notifications** — office-wide and personal due-date views, reminders, overdue alerts, and assignment notifications.
7. **Dashboard and reports** — upcoming/overdue obligations, workload, client status, filing/payment progress, and office performance.
8. **Tax research and knowledge library** — searchable laws, executive regulations, circulars, instructions, rulings, court judgments, committee decisions, office templates, and internal notes.
9. **Similar tax cases library** — structured facts, disputed issue, tax type, legal basis, evidence, committee/court outcome, appeal memorandum, and reusable lessons.

### Later capabilities
- Client self-service portal and secure upload links.
- OCR and assisted document extraction.
- AI-assisted search, summarization, and drafting grounded in office-approved sources.
- Billing, subscription management, and usage metering.
- External integrations and workflow automation.

AI output is assistive only. It must show its sources, distinguish extracted facts from suggestions, and never represent itself as an authoritative tax ruling or submit/approve a tax position without human review.

## 4. Egyptian tax domain

The product is designed around Egyptian tax administration and the office's work, including (subject to legal validation and configurable applicability):
- Value Added Tax (VAT)
- Corporate income tax
- Payroll tax
- Withholding tax
- Stamp tax
- Real estate tax and other applicable obligations

Tax types, filing frequencies, periods, deadlines, forms, rates, and eligibility rules must be configurable and versioned. Do not hard-code a legal deadline or tax rate without a verified source, effective date, and review status.

TaxOS tracks obligations and supporting work. It does not claim to file directly with ETA unless a future, separately approved and officially supported integration is established. It is not an e-invoicing system.

## 5. Obligation lifecycle

The default workflow is:

**Draft → In Progress → Ready for Review → Approved → Filed → Paid → Closed**

The workflow must retain status history, actor, timestamp, notes, supporting evidence, and any return/reopen reason. Offices may configure optional steps, but terminal states and audit history must remain explicit. Filing and payment are separate events and must not be inferred from one another.

Each obligation should support:
- Client and tax type
- Tax period and applicable legal basis
- Due date and source/verification status
- Responsible preparer and reviewer
- Required documents and checklist
- Work status and review outcome
- Filing reference / receipt details when supplied by the user
- Payment amount, date, reference, and evidence when supplied by the user
- Notes, correspondence, and full activity history

## 6. Architecture guardrails

- **Frontend:** Flutter, mobile-first, with web/desktop surfaces considered for office administration where justified.
- **Backend:** Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions).
- **Application structure:** feature-first and Clean Architecture.
- **Localization:** Arabic-first UX with English support; RTL and LTR must both be supported.
- **Currency and dates:** Egyptian pound (EGP) and Egyptian locale defaults, while allowing multiple currencies and explicit date/period formats where client work requires them.
- **Security:** strict office-level tenant isolation, least-privilege role access, private document storage, and auditable privileged actions.
- **Data model:** office/tenant, user identity, office membership, role/permission, client, tax profile, obligation, workflow event, task, document, notification, and research/case records are distinct concepts.

### Mandatory architecture decision before expanding the schema

The current database migrations describe one authenticated accountant as one isolated tenant. That model is not sufficient for an office with multiple employees. Before adding further business modules or applying migrations to a hosted environment, define and test the office membership model, role boundaries, and tenant-scoped foreign-key integrity. Do not retrofit this by changing existing production data without an approved migration and rollback plan.

## 7. Explicit exclusions

- US federal/state tax filing, IRS Form 1040, W-2, 1099, and US-only tax calculations.
- Consumer-first expense tracking as the product's primary workflow.
- Direct ETA filing or portal automation without a verified and approved integration path.
- E-invoicing and ERP integration as the core product.
- Autonomous AI tax opinions, automatic legal conclusions, or unreviewed submissions.

## 8. Delivery order

1. **Product and architecture alignment:** reconcile the legacy US-oriented vision, PRD, roadmap, security, and database documentation with this baseline.
2. **Tenant foundation:** settle office, membership, role, authorization, and cross-tenant integrity design; write tests before expanding schema.
3. **Office and client foundation:** authentication, office setup, invitations, client registry, tax profiles, audit history.
4. **Obligation MVP:** obligation registry, due-date source/verification, assignments, workflow, checklists, calendar, and reminders.
5. **Documents and reporting:** secure evidence management, dashboard, and office reports.
6. **Knowledge foundation:** tax research and similar-case library with source metadata and review status.
7. **Advanced capabilities:** OCR, client portal, AI assistance, billing, and integrations after the core workflow is secure and proven.

## 9. Acceptance principles

A release is not complete merely because screens or tables exist. Each capability requires:
- User stories and acceptance criteria tied to office roles.
- Tenant-isolation and authorization tests.
- Migration dry-run and rollback evidence for schema changes.
- Automated tests for core domain rules and workflow transitions.
- Arabic/RTL and English/LTR usability coverage.
- Security review for tax data and document access.
- Documentation that matches the implemented behavior.

No production database migration, deployment, or data mutation is authorized by this product baseline.
