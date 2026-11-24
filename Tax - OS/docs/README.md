# TaxOS Documentation

## Product authority

| Document | Description |
|----------|-------------|
| [13_EGYPTIAN_FIRM_PRODUCT_BASELINE.md](13_EGYPTIAN_FIRM_PRODUCT_BASELINE.md) | Approved product direction and Egyptian accounting-firm v1 baseline |

**Product direction:** TaxOS is a SaaS operating system for Egyptian accounting and tax advisory firms. Older consumer/US-oriented product documents are legacy and must be reconciled before implementation is based on them.

## Architecture and delivery

| Document | Description |
|----------|-------------|
| [14_OFFICE_TENANCY_AND_MEMBERSHIP_MODEL.md](14_OFFICE_TENANCY_AND_MEMBERSHIP_MODEL.md) | Proposed multi-office tenant, employee membership, role, RLS, relational integrity, and migration model |\n| [15_EXISTING_SCHEMA_AUDIT_AND_MIGRATION_READINESS.md](15_EXISTING_SCHEMA_AUDIT_AND_MIGRATION_READINESS.md) | Audit of the current US-oriented schema, tenancy/security gaps, and safe migration gates |\n| [16_EGYPTIAN_TAX_DOMAIN_AND_OBLIGATION_MODEL.md](16_EGYPTIAN_TAX_DOMAIN_AND_OBLIGATION_MODEL.md) | Proposed Egyptian client, tax registration, obligation, workflow, filing, payment, evidence, and audit domain model |\n| [17_LOGICAL_ERD_AND_LEGACY_TABLE_DISPOSITION.md](17_LOGICAL_ERD_AND_LEGACY_TABLE_DISPOSITION.md) | Logical entities, relationships, tenant integrity rules, conceptual ERD, and legacy table keep/replace/defer decisions |\n| [18_REPOSITORY_AND_IMPLEMENTATION_READINESS.md](18_REPOSITORY_AND_IMPLEMENTATION_READINESS.md) | Actual Git-tree implementation audit and safe Flutter-first delivery sequence |
| [00_PROJECT_RULES.md](00_PROJECT_RULES.md) | Project rules and contributor requirements |
| [01_PRODUCT_VISION.md](01_PRODUCT_VISION.md) | Legacy product vision; pending reconciliation with DOC-13 |
| [02_PRD.md](02_PRD.md) | Legacy US-oriented PRD; pending replacement with Egyptian firm requirements |
| [03_ARCHITECTURE.md](03_ARCHITECTURE.md) | Architecture and technical constraints |
| [04_DATABASE.md](04_DATABASE.md) | Legacy database design; requires reconciliation with DOC-14 |
| [08_SECURITY.md](08_SECURITY.md) | Legacy security requirements; requires Egyptian firm and membership alignment |
| [09_ROADMAP.md](09_ROADMAP.md) | Legacy roadmap; pending reconciliation with DOC-13 |
| [architecture/OVERVIEW.md](architecture/OVERVIEW.md) | System design and layer boundaries |
| [api/SUPABASE.md](api/SUPABASE.md) | Supabase schema, auth, and API conventions |
| [deployment/ENVIRONMENTS.md](deployment/ENVIRONMENTS.md) | Dev, staging, and production setup |
| [onboarding/DEVELOPER_SETUP.md](onboarding/DEVELOPER_SETUP.md) | Local development guide |
| [adr/](adr/) | Architecture Decision Records |

## Implementation rule

Do not implement features from legacy US-oriented requirements. DOC-15 confirms that the existing SQL migrations are a solo-accountant / US tax-return foundation and must not be mechanically converted into the Egyptian firm product. Reconcile the numbered product, architecture, database, security, and roadmap documents with DOC-13 and DOC-14 before treating them as implementation-ready. DOC-14 is a proposed target design, not an approved or executable migration. No hosted database migration or production deployment is authorized by these documents.
