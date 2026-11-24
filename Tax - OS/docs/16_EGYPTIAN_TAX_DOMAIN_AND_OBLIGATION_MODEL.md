# TaxOS — Egyptian Tax Domain and Obligation Model

**Document ID:** DOC-16  
**Version:** 0.1  
**Status:** Proposed domain specification for review; not an executable schema  
**Date:** 24 November 2026  
**Depends on:** DOC-13, DOC-14, DOC-15

## 1. Purpose and design principles

Define the Egyptian tax operations domain that will replace the legacy US individual-return assumptions. This document is a product/domain specification. It does not authorize SQL migrations, hosted database changes, tax calculations, legal deadline automation, or ETA integration.

Core principles:

1. The accounting office is the tenant; clients/taxpayers are records managed by that office.
2. A client may have multiple tax registrations, branches, activities, tax types, and obligations.
3. An obligation represents a tax responsibility for a defined taxpayer and period/event.
4. A task represents work performed by the office. It is not the tax obligation itself.
5. Filing and payment are separate recorded events. Neither may be inferred from the obligation's workflow status.
6. Statutory rules, deadlines, forms, rates, thresholds, and applicability must be versioned and source-backed.
7. TaxOS tracks work and evidence. It does not claim to submit to the ETA unless an approved integration is separately designed.
8. All tenant-owned records must be firm-scoped, auditable, and protected by RLS plus relational constraints.

## 2. Domain map

### 2.1 Core concepts

| Concept | Meaning | Example |
|---|---|---|
| Firm | Accounting office / SaaS tenant | Tax advisory office |
| Client | Legal person or natural person served by the office | Company, sole proprietor, individual |
| Tax registration | A client's registration under a tax regime/type | VAT registration |
| Branch / establishment | A registered or operational location belonging to a client | Main office, branch |
| Tax type | A configurable category of tax responsibility | VAT, corporate income tax, payroll tax |
| Tax period | A period to which a tax obligation relates | Month, quarter, tax year, event date |
| Obligation | A specific required filing, payment, declaration, or compliance action | VAT return for a defined month |
| Work item | Office work required to complete an obligation | Prepare VAT return |
| Review | Independent check and approval/rejection of prepared work | Reviewer approval |
| Filing event | Evidence that a filing/submission occurred | ETA receipt/reference entered by user |
| Payment event | Evidence of a tax payment or installment | Payment receipt/reference |
| Document | Source evidence or work product | Invoice, payroll report, receipt |
| Activity event | Immutable record of a material action/change | Assignment, status change, review decision |

### 2.2 Important distinctions

- A client is not a tax registration. One client can have multiple registrations.
- A tax type is not a tax period. The same tax type repeats across periods.
- An obligation is not a task. One obligation may require several tasks and review steps.
- A task marked complete does not mean the obligation is filed.
- A filed obligation is not necessarily paid.
- A payment record does not by itself prove that the correct return was filed.
- A due date is a legal/compliance fact with a source and effective period, not merely a date typed into a calendar.

## 3. Client and taxpayer model

### 3.1 Client record

The client is the office's primary relationship record.

Proposed fields:

| Field | Purpose / rule |
|---|---|
| `id` | Stable client identifier |
| `firm_id` | Owning office tenant |
| `client_code` | Office-defined unique reference |
| `display_name` | Name used in lists and UI |
| `legal_name_ar`, `legal_name_en` | Legal name in Arabic and English, when available |
| `client_type` | Controlled type: company, sole_proprietor, individual, partnership, non_profit, other |
| `legal_form` | Configurable legal-form reference; do not hard-code an exhaustive legal list in application code |
| `status` | prospect, active, inactive, archived |
| `primary_contact_id` | Optional preferred contact |
| `default_currency` | Defaults to EGP; support other currencies where needed |
| `notes` | Internal notes subject to access/audit policy |
| `created_at`, `updated_at`, `archived_at` | Lifecycle timestamps |

A client may be an entity or an individual. Avoid making an Egyptian national ID, commercial registration number, or tax registration number mandatory for every client type. Applicability and validation differ by legal form and registration.

### 3.2 Client identifiers

Do not put every identifier into a single generic `tax_id` field.

Use a separate identifier collection with:

- identifier type (e.g. tax registration number, unified tax registration number if applicable, commercial registration number, national ID, other official reference);
- normalized value or protected encrypted value/reference;
- issuing authority / jurisdiction;
- issue/expiry dates where relevant;
- verification status, verification source, verifier, and timestamp;
- masked display value;
- whether it is primary for a specific purpose.

Sensitive identifiers must not be exposed in logs, analytics, URLs, notification payloads, or broad search indexes. The final list of identifier types and encryption approach requires Egyptian legal/product and security review.

### 3.3 Contacts and branches

A client can have multiple contacts and branches.

Contacts should support name, role/title, email, phone, preferred language, contact permissions, and active status. Do not assume that every contact is authorized to receive tax documents or approve submissions.

Branches should support branch name/code, address, operational status, and optional official registration reference. A branch belongs to one client and one firm.

### 3.4 Client relationship and assignments

For MVP, all active firm members with appropriate permissions can access the firm's clients (office-wide visibility, per DOC-14). Assignment fields identify operational responsibility; they are not the tenant security boundary.

Proposed client-level responsibility fields:
- relationship owner / account manager;
- primary preparer;
- default reviewer;
- optional backup owner.

Later, if customer evidence requires assigned-client visibility, introduce a separate `client_assignments` authorization model and tests. Do not imply row-level restrictions before that feature exists.

## 4. Tax registrations and profiles

A client may have zero, one, or many tax registrations.

A registration should represent a specific registration relationship with an authority/regime, not a duplicate client record.

Proposed fields:

- `id`, `firm_id`, `client_id`;
- `tax_type_id` or registration category;
- registration/reference number (protected where sensitive);
- authority / tax office reference, if known;
- registration status: pending, active, suspended, cancelled, closed, unknown;
- effective-from and effective-to dates;
- registration evidence/document links;
- source and verification status;
- notes and audit timestamps.

A broader tax profile can capture applicability and operating facts used by the office, such as accounting year-end, business activity, legal form, VAT status, payroll headcount, export/import indicators, and other facts. Each fact needs an effective date and source where it can change legal applicability.

Do not store calculated legal conclusions as permanent profile facts. For example, a VAT applicability decision should be represented with its basis, source, reviewer, effective period, and review state.

## 5. Tax type catalogue

Tax types are reference data with controlled, stable keys and editable display labels.

Initial candidate catalogue (subject to legal and product validation):

| Key (proposed) | Arabic display label | Notes |
|---|---|---|
| `vat` | ضريبة القيمة المضافة | Filing/payment obligations depend on registration and applicable rules |
| `corporate_income_tax` | ضريبة الدخل على الشركات والأشخاص الاعتبارية | Annual return and related obligations; do not hard-code one period rule for every case |
| `individual_business_income_tax` | ضريبة الدخل على الأشخاص الطبيعيين / النشاط التجاري | Applicability and forms depend on taxpayer profile |
| `payroll_tax` | ضريبة المرتبات وما في حكمها | May include recurring declarations and related compliance |
| `withholding_tax` | ضريبة الخصم والتحصيل تحت حساب الضريبة | May have multiple transaction/category-specific responsibilities |
| `stamp_tax` | ضريبة الدمغة | Event/transaction-driven obligations may apply |
| `real_estate_tax` | ضريبة العقارات المبنية | Different periods, assessments, and payment events may apply |
| `other` | التزامات ضريبية أخرى | Requires explicit description and source; not a way to hide unsupported tax logic |

Do not assume that every tax type applies to every client. Applicability must be represented separately and may require reviewer confirmation.

Each tax type should include:
- stable key and localized labels;
- description and scope;
- active/retired status;
- default obligation templates (if any);
- allowed period types;
- required evidence/checklists;
- links to effective-dated legal rule records.

Tax types must not store a single universal tax rate or due-day number.

## 6. Tax periods and obligation generation

### 6.1 Period model

A tax period is a bounded or event-based reference for an obligation.

Supported period kinds should include:
- monthly;
- quarterly;
- annual / fiscal year;
- custom date range;
- event-driven (transaction, registration, cessation, transfer, assessment, or another legally defined event).

Store explicit `period_start` and `period_end` when applicable. Event-driven obligations need an `event_date` and event type. Store the fiscal year/calendar convention used to derive the period. Do not assume every client uses the calendar year.

### 6.2 Obligation template vs generated obligation

Separate reusable obligation templates from actual obligations.

A template can define:
- tax type;
- applicable client/registration conditions;
- period-generation rule;
- legal deadline rule reference;
- default checklist;
- default workflow;
- whether the template is active and its effective dates.

A generated obligation is a specific instance for one client, one tax type, and one period/event. It must retain the template/rule version used at generation time.

Generation must be idempotent: rerunning a schedule must not create duplicate obligations for the same firm, client, registration, tax type, period, and obligation kind.

### 6.3 Legal due date and source

A due date must carry provenance.

Proposed due-date fields:
- calculated or manually entered due date;
- due-date basis/type (statutory, authority notice, approved extension, office target, manually overridden);
- legal source/reference and relevant article/decision/circular;
- source publication/effective date;
- rule version used;
- verification status: unverified, pending_review, verified, superseded;
- verified by and verified at;
- override reason, actor, timestamp, and previous value.

The system may display an unverified proposed date, but it must not present it as a confirmed statutory deadline. A manually changed date must never erase the original rule-derived date or its audit trail.

Do not implement live statutory deadline calculation until the tax rule catalogue is researched, versioned, and reviewed by a qualified Egyptian tax professional.

## 7. Tax obligation entity

A tax obligation represents a specific compliance responsibility for a client.

Proposed fields:

| Field | Description |
|---|---|
| `id` | Stable obligation identifier |
| `firm_id` | Owning office |
| `client_id` | Taxpayer/client |
| `tax_registration_id` | Relevant registration, nullable only where the obligation is not registration-based |
| `tax_type_id` | Tax type |
| `obligation_kind` | return, payment, declaration, information_request, assessment, objection_deadline, other |
| `period_kind` | monthly, quarterly, annual, custom, event |
| `period_start`, `period_end` | Applicable bounded period |
| `event_date`, `event_type` | For event-driven obligation |
| `tax_year_label` | Human-readable fiscal year reference where useful |
| `legal_due_date` | Verified or proposed date with source metadata |
| `office_target_date` | Internal target date; separate from legal due date |
| `status` | Workflow status described in section 8 |
| `priority` | normal, high, urgent; operational only |
| `assigned_preparer_id` | Responsible active firm member |
| `assigned_reviewer_id` | Reviewer, where required |
| `estimated_amount` | Optional estimate, not an assessed amount |
| `final_declared_amount` | Optional amount from prepared/approved return |
| `currency` | ISO currency; default EGP |
| `external_reference` | User-entered ETA/authority reference, if supplied |
| `created_by`, `created_at`, `updated_at` | Audit metadata |
| `closed_at`, `closed_by` | Closure metadata |

Amounts must be semantically distinct. Do not use one `tax_amount` field for estimate, declared liability, assessed liability, and amount paid.

### 7.1 Uniqueness and amendments

The business key should prevent duplicate active obligations for the same client, registration, tax type, kind, and period. The exact unique constraint must account for nullable registration and event-driven cases.

An amended or corrected filing should not silently overwrite the original filing event. Model a new filing event/version linked to the prior event, preserving the original submission reference and evidence.

An assessment, objection, appeal, or authority information request may create a linked follow-up obligation with its own trigger date, due date, status, and evidence. It should not be squeezed into a normal recurring return.

## 8. Obligation workflow

Default lifecycle:

`draft → in_progress → ready_for_review → approved → filed → paid → closed`

Status definitions:

| Status | Meaning | Minimum exit condition |
|---|---|---|
| `draft` | Obligation created but not yet accepted into active work | Required identity, tax type, and period validated |
| `in_progress` | Preparation and evidence collection underway | Required checklist and preparer work completed |
| `ready_for_review` | Preparer says the work is complete and requests review | Review assignment and required workpaper/evidence present |
| `approved` | Authorized reviewer approved the prepared position/work | Reviewer decision recorded with actor, time, and notes |
| `filed` | A filing/submission event has been recorded with evidence/reference or an explicitly documented exception | Filing event recorded; no assumption that payment occurred |
| `paid` | Payment event(s) recorded as satisfying the tracked amount or marked reconciled under an approved policy | Payment evidence and reconciliation state recorded |
| `closed` | Office has completed its work and required follow-up | Closure checklist and actor/reason recorded |

### 8.1 Exceptional states and transitions

Do not use a single linear status field to hide exceptions. Support explicit actions/events for:
- return to preparer / changes requested;
- rejection by reviewer;
- reopened after filing or closure;
- cancelled / not applicable with reason and approver;
- overdue as a derived flag based on verified due date and current state, not a terminal workflow status;
- disputed or under objection, represented by linked case/obligation records where needed.

Every transition must be validated server-side. Store previous status, new status, actor, timestamp, reason, and relevant evidence. Client-side UI checks are not authorization.

### 8.2 Separation of responsibilities

The preparer must not approve their own work by default. Any exception (e.g. sole practitioner office) should be an explicit firm policy with an auditable override, not a hidden bypass.

The reviewer role and permission should be distinct from task assignment. A manager may assign work without being the tax reviewer.

## 9. Work items, checklists, and review

One obligation can have multiple work items.

Proposed work item fields:
- `id`, `firm_id`, `obligation_id`;
- title, description, work type;
- status: open, in_progress, blocked, completed, cancelled;
- assigned user, creator, due date, priority;
- dependency links;
- completion notes and completion evidence;
- created/updated/completed timestamps.

Checklist templates should be versioned and copied to the obligation/work item when instantiated. Editing a template later must not silently change historical checklists.

Review decisions should be separate records:
- reviewer;
- decision: approved, changes_requested, rejected;
- comments/findings;
- supporting document links;
- decision timestamp;
- optional next reviewer/escalation.

## 10. Filing events

A filing event records what the office knows happened at the authority.

Proposed fields:
- `id`, `firm_id`, `obligation_id`;
- filing type: original, amended, corrected, supplementary, other;
- submitted_at (timestamp/date as evidenced);
- submission channel: ETA portal, in-person, authorized representative, other, unknown;
- authority/ETA reference number;
- receipt/acknowledgement status;
- evidence document(s);
- recorded_by and recorded_at;
- notes;
- supersedes_filing_event_id, where applicable.

A filing event is a user-recorded fact unless an approved integration independently confirms it. UI wording must distinguish "recorded by office" from "verified through integration".

## 11. Payment events and reconciliation

An obligation can have multiple payments, installments, offsets, refunds, or corrections where applicable.

Proposed payment event fields:
- `id`, `firm_id`, `obligation_id`;
- event type: payment, installment, refund, reversal, offset, adjustment;
- amount and ISO currency;
- payment/effective date;
- payment channel/method, optional;
- authority/payment reference;
- evidence document(s);
- recorded_by and recorded_at;
- reconciliation status: unverified, pending_review, reconciled, disputed;
- notes.

Do not automatically set an obligation to `paid` merely because a payment event exists. The system needs an explicit reconciliation rule for full/partial payment, adjustments, offsets, and refunds. Until approved, show paid amount, outstanding amount (when determinable), and reconciliation state separately.

## 12. Documents and evidence links

Documents are stored once and may be linked to:
- client;
- tax registration;
- obligation;
- work item;
- filing event;
- payment event;
- review decision;
- tax research/case record.

Use explicit link records or well-defined relationship tables rather than relying on arbitrary JSON references. Each link must validate that all records belong to the same firm and, where required, the same client/obligation.

Document metadata should include:
- category/type;
- title and description;
- original filename, MIME type, size, storage key;
- upload source and uploader;
- document date and received date where distinct;
- version/supersedes relationship;
- verification status;
- confidentiality/access classification;
- retention/legal-hold metadata where applicable.

The storage bucket remains private. A signed URL is a short-lived access mechanism, not a permanent document URL. Never store secrets or sensitive identifiers in storage object names.

## 13. Audit trail and activity timeline

Record append-only activity events for material business changes, including:
- client and registration changes;
- obligation creation, due-date verification/override, and status transitions;
- assignment changes;
- checklist completion;
- review decisions;
- filing and payment events;
- document upload, replacement, and link/unlink actions;
- cancellation, reopening, and closure;
- membership/role changes that affect access.

Each event should include firm, actor, action, entity type/id, timestamp, safe before/after diff or structured metadata, reason, and correlation/request ID where available.

Do not log full tax identifiers, document contents, access tokens, or unnecessary personal data. Audit log write permissions must be server-controlled; ordinary clients must not edit or delete historical audit events.

## 14. Notifications and calendar

Notifications are generated from business events and due-date rules. Each notification should identify:
- recipient user;
- firm;
- event type;
- related entity;
- delivery channel and delivery state;
- scheduled/sent/read timestamps;
- deduplication key.

Calendar entries should distinguish:
- verified statutory due dates;
- unverified proposed due dates;
- office target dates;
- task deadlines;
- review dates;
- filing/payment appointments.

Notification delivery failure must not alter an obligation's status. Reminder scheduling must be idempotent and respect user/firm preferences and time zone.

## 15. MVP delivery boundaries

### Include in first tax-operations release

1. Client registry with legal name, client type, contacts, identifiers (securely handled), and archive state.
2. Tax registrations and a basic tax applicability profile with source/review fields.
3. Configurable tax type catalogue with initial Egyptian candidate types.
4. Manual obligation creation for a client, tax type, period, due date, and responsible preparer/reviewer.
5. Due-date source and verification status; no unverified automated statutory calculations.
6. Obligation workflow with status history and reviewer decision.
7. Tasks/checklists attached to obligations.
8. Document upload and explicit client/obligation links.
9. Manual filing and payment event recording with receipt/reference evidence.
10. Dashboard/calendar queries for upcoming, overdue, in-review, filed, and unpaid work.

### Defer until the core is proven

- Automated statutory deadline engine and recurring obligation generation.
- Tax calculations, return form generation, and tax-position recommendations.
- ETA API/portal integration or robotic browser automation.
- E-invoicing and ERP integrations.
- Client portal and direct client approval.
- OCR and autonomous document classification.
- AI-generated legal/tax conclusions.
- Complex multi-entity groups, consolidated obligations, and custom workflow builders.

## 16. Required domain and acceptance tests

1. A firm cannot access another firm's clients, registrations, obligations, tasks, documents, filing events, or payment events.
2. One client can have multiple registrations and tax types without duplicate client records.
3. An obligation must reference a client and registration belonging to the same firm; a registration must belong to the selected client.
4. An obligation period must be valid for its period kind; event-driven obligations must have the required event metadata.
5. Duplicate generation of the same obligation does not create duplicates.
6. A due date cannot be represented as verified without source/reviewer metadata.
7. An override preserves the original due date and records actor, reason, and timestamp.
8. Invalid status transitions are rejected by the database/API.
9. A preparer cannot approve their own work unless an explicit, audited firm exception applies.
10. Task completion does not automatically set the obligation to filed or paid.
11. Filing and payment are independently recorded and independently evidenced.
12. Partial payments do not incorrectly mark the obligation fully paid.
13. Amended filings preserve prior filing events and references.
14. Documents cannot be linked across firms or to mismatched client/obligation parents.
15. Audit history cannot be modified by ordinary authenticated users.
16. Notifications are idempotent and delivery failures do not mutate tax workflow state.
17. Arabic/English labels and RTL/LTR layouts do not alter stored stable keys or business rules.

## 17. Decisions requiring product/legal approval

| Decision | Proposed default | Approval needed from |
|---|---|---|
| MVP client visibility | Office-wide for active members with permission | Product / security |
| Initial tax catalogue | Candidate types in section 5; configurable | Egyptian tax reviewer |
| Due-date automation | Manual date plus source/verification first | Product / tax reviewer |
| Period generation | Manual obligations first; templates later | Product |
| Approval policy | Preparer/reviewer separation; explicit sole-practitioner exception | Product / office users |
| Payment completion | Reconciliation required; no auto-paid from a single event | Product / tax reviewer |
| Identifier handling | Separate typed identifiers; encryption/masking for sensitive values | Security / legal |
| Amendments | Preserve each filing event as a versioned record | Product / tax reviewer |
| ETA integration | Out of MVP; no portal automation | Product / legal / security |

## 18. Release gate

This specification must be reviewed before SQL design begins. The next engineering artifact should be a logical ERD and a table-by-table mapping of retained legacy tables versus new Egyptian-domain tables. Only after that review should a disposable-local-database schema prototype be authored.

No production or staging migration, tax rule automation, ETA integration, or legal conclusion is authorized by DOC-16.
