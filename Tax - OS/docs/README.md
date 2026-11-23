# TaxOS Documentation

## Product authority

| Document | Description |
|----------|-------------|
| [13_EGYPTIAN_FIRM_PRODUCT_BASELINE.md](13_EGYPTIAN_FIRM_PRODUCT_BASELINE.md) | Approved product direction and Egyptian accounting-firm v1 baseline |

**Product direction:** TaxOS is a SaaS operating system for Egyptian accounting and tax advisory firms. Older consumer/US-oriented product documents are legacy and must be reconciled before implementation is based on them.

## Architecture and delivery

| Document | Description |
|----------|-------------|
| [00_PROJECT_RULES.md](00_PROJECT_RULES.md) | Project rules and contributor requirements |
| [01_PRODUCT_VISION.md](01_PRODUCT_VISION.md) | Legacy product vision; pending reconciliation with DOC-13 |
| [02_PRD.md](02_PRD.md) | Legacy US-oriented PRD; pending replacement with Egyptian firm requirements |
| [03_ARCHITECTURE.md](03_ARCHITECTURE.md) | Architecture and technical constraints |
| [04_DATABASE.md](04_DATABASE.md) | Database design; requires office-membership and tenant-model reconciliation |
| [08_SECURITY.md](08_SECURITY.md) | Security requirements |
| [09_ROADMAP.md](09_ROADMAP.md) | Legacy roadmap; pending reconciliation with DOC-13 |
| [architecture/OVERVIEW.md](architecture/OVERVIEW.md) | System design and layer boundaries |
| [api/SUPABASE.md](api/SUPABASE.md) | Supabase schema, auth, and API conventions |
| [deployment/ENVIRONMENTS.md](deployment/ENVIRONMENTS.md) | Dev, staging, and production setup |
| [onboarding/DEVELOPER_SETUP.md](onboarding/DEVELOPER_SETUP.md) | Local development guide |
| [adr/](adr/) | Architecture Decision Records |

## Implementation rule

Do not implement features from legacy US-oriented requirements. Reconcile the numbered product, architecture, database, security, and roadmap documents with DOC-13 before treating them as implementation-ready. No hosted database migration or production deployment is authorized by DOC-13.
