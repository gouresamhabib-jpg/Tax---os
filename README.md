# TaxOS

TaxOS is an enterprise-grade Operating System for Egyptian Accounting Firms.

It helps accounting firms manage clients, tax obligations, workflows, documents, tax research, similar tax cases, internal knowledge, and future AI-powered decision support.

TaxOS is designed as a multi-tenant SaaS platform capable of serving thousands of accounting firms while preserving complete data isolation.

The platform is not intended to replace the Egyptian Tax Authority portal.

Instead, it provides accountants with a centralized workspace for managing all tax-related activities.

## Vision

Build the digital operating system for accounting firms in Egypt.

TaxOS should become the primary workspace where accountants perform their daily work.

The more the office uses TaxOS, the smarter and more valuable it becomes.

## Product Philosophy

TaxOS is not a task manager.

TaxOS is not only a CRM.

TaxOS transforms daily accounting work into reusable organizational knowledge.

Every action enriches the firm's experience.

Every completed case improves future decisions.

## Architecture

- **Feature-first** — code is organized by business capability, not technical layer
- **Clean Architecture** — each feature has `data`, `domain`, and `presentation` layers
- **Monorepo-ready** — `apps/mobile` holds the Flutter shell; `lib/` holds application logic

## Repository structure

| Path | Purpose |
|------|---------|
| `apps/mobile/web/admin/backend/` | Flutter project (platform targets, pubspec, entry point) |
| `lib/` | Application source — features, core, app config |
| `assets/` | Shared static assets (fonts, icons, images) |
| `database/` | Supabase migrations, RLS policies, seeds, edge functions |
| `docs/` | Architecture, API, deployment, and onboarding documentation |
| `scripts/` | Setup, deployment, and codegen automation |
| `.github/` | CI/CD workflows and issue/PR templates |
| `.cursor/` | Cursor IDE rules and agent skills |

## Core Modules

• Dashboard

• Companies

• Tax Obligations

• Workflow Engine

• Timeline Engine

• Documents

• Calendar

• Notifications

• Reports

• Office CRM

• Tax Research Center

• Similar Cases Library

• Knowledge Center

• Office Brain

• AI Assistant (Future)

• Client Portal (Future)

• Billing & Subscription (Future)

TaxOS includes a professional tax research platform.

It stores

• Tax Laws

• Executive Regulations

• Circulars

• Internal Instructions

• Tax Rulings

• Court Judgments

• Committee Decisions

• Office Templates

• Internal Notes

• Similar Cases

## Similar Cases

Accounting firms can build a searchable library of previous tax cases.

Each case contains

• Facts

• Tax Office

• Tax Type

• Legal Basis

• Articles

• Committee Decision

• Appeal Memorandum

• Supporting Documents

• Outcome

• Keywords

This allows accountants to reuse previous experience instead of starting from scratch.

## Knowledge Engine

TaxOS continuously builds the firm's internal knowledge.

Every completed task can generate

• Checklists

• Playbooks

• Templates

• Lessons Learned

• Best Practices

The office becomes smarter over time.

## Office Brain

Future AI modules will analyze the firm's accumulated experience.

Examples

"What documents are usually requested?"

"Show similar VAT objections."

"What cases succeeded using Article 30?"

"Which companies have recurring issues?"

Architecture Principles

• Multi Tenant

• Offline First

• Event Driven Timeline

• Knowledge Graph Ready

• AI Ready

• Domain Driven Design

• Clean Architecture

• SOLID

• Repository Pattern

Future Modules

OCR

Voice Notes

Document AI

WhatsApp Integration

Email Integration

Client Portal

Electronic Signature

Knowledge Graph

Semantic Search

AI Legal Assistant

Predictive Risk Analysis

## Prerequisites

- Flutter SDK (stable channel)
- Dart SDK (bundled with Flutter)
- Supabase CLI
- Node.js 20+ (for scripts and Supabase tooling)

## Getting started

> Detailed setup instructions live in [docs/onboarding/DEVELOPER_SETUP.md](docs/onboarding/DEVELOPER_SETUP.md).

1. Clone the repository
2. Install Flutter dependencies: `cd apps/mobile && flutter pub get`
3. Configure Supabase (see `docs/api/SUPABASE.md`)
4. Run migrations from `database/migrations/`
5. Launch the app: `flutter run`

## Documentation

- [Architecture overview](docs/architecture/OVERVIEW.md)
- [Supabase integration](docs/api/SUPABASE.md)
- [Deployment](docs/deployment/ENVIRONMENTS.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## License

Proprietary — see [LICENSE](LICENSE). Unauthorized use, copying, or distribution is prohibited.
