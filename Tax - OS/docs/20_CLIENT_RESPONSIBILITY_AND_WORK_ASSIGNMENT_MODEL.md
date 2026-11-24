# TaxOS — Client Responsibility and Work Assignment Model

**Document ID:** DOC-20  
**Version:** 0.1  
**Status:** Proposed implementation design; not an approved production migration  
**Date:** 24 November 2026  
**Depends on:** DOC-14, DOC-17, DOC-19

## 1. Purpose

Define how an accounting office assigns operational responsibility for clients and separately assigns work. This model preserves the confirmed MVP rule: all active members of a firm can see all clients in that firm. Assignment is for accountability and workflow routing, not access control.

The accompanying SQL is an additive prototype extension for the isolated `taxos_prototype` schema. It is not a Supabase migration and has not been executed against PostgreSQL.

## 2. Confirmed product behavior

1. Every active firm member retains office-wide visibility of every client in that firm.
2. A client may have one active primary responsible employee.
3. A client may also have multiple active supporting employees.
4. Client responsibility and task ownership are independent. Changing a client's primary responsible employee does not automatically reassign existing tasks.
5. Each work item has one assignee and may have one separate reviewer.
6. A task assignee and reviewer must be different memberships.
7. Reassignment history records the previous assignment, new assignment, actor, event time, and optional reason.
8. Assignment references are firm-scoped memberships, not bare user IDs.
9. Archived clients cannot receive new assignments or new work items.
10. Assignment never grants access to a different firm and never removes office-wide visibility within the current firm.

## 3. Proposed entities

| Entity | Purpose | Important relationships |
|---|---|---|
| `client_assignments` | Current and historical primary/supporting client responsibility | Firm, client, assigned membership, assigning membership |
| `client_assignment_events` | Append-only assignment and closure history | Firm, client, assignment, actor membership |
| `work_items` | Individual tasks linked to a client | Firm, client, assignee membership, optional reviewer membership, creator |
| `work_item_assignment_events` | Append-only assignee/reviewer assignment history | Firm, work item, previous/new memberships, actor |

### 3.1 Client assignments

- `assignment_role` is `primary` or `supporting`.
- Only one active primary assignment may exist per client.
- A member cannot have duplicate active assignments of the same role for one client.
- Reassignment closes the previous row with `ended_at` and `ended_by_membership_id`, then inserts a new row. This preserves the previous responsibility period.
- A client may temporarily have no primary responsible employee; the UI should surface this as an unassigned-client queue.
- Assignment changes are performed by owner, admin, or manager in this prototype.

### 3.2 Work items

- A work item is a unit of office work, not a tax obligation status.
- Initial statuses: `todo`, `in_progress`, `blocked`, `completed`, `cancelled`.
- Initial priorities: `low`, `normal`, `high`, `urgent`.
- Each work item belongs to one client and one firm.
- The assignee is required; the reviewer is optional.
- Owner/admin/manager may create, assign, and reassign work.
- The assignee or reviewer may update task progress; assignment changes remain manager-controlled.
- Review decisions and approval workflow are a separate future slice; `reviewer_membership_id` only routes review responsibility and does not itself approve tax work.

## 4. Authorization and tenant integrity

- All reads are scoped to an active membership in the row's firm. This includes client assignments, work items, and assignment history.
- Assignment writes are restricted to active owner/admin/manager memberships.
- Work item progress updates are allowed to the assigned employee and designated reviewer, as well as owner/admin/manager.
- A trigger prevents a non-manager from changing the assignee, reviewer, client, or firm, even if that user can update task progress.
- Every relationship to a client or membership uses composite `(firm_id, id)` foreign keys.
- Database triggers verify that the assigned membership is active when a new assignment is created or changed. Foreign keys alone cannot enforce active membership status.
- History tables have no direct authenticated insert/update/delete grants. A database trigger writes events.
- No client-assignment filter is added to RLS. Assignment does not narrow the office-wide client visibility decision.

## 5. Lifecycle and audit behavior

### Client responsibility

1. Manager selects a client and an active firm member.
2. The system creates a primary or supporting assignment and records the actor and timestamp.
3. To replace a primary assignee, close the existing active primary assignment and create the new one in the same transaction.
4. The event history retains both the old and new responsibility periods.
5. If an employee is suspended or revoked, assignment cleanup/reallocation is an explicit membership-lifecycle operation; it must not silently delete history.

### Work assignment

1. Manager creates a work item and selects its assignee, optional reviewer, priority, and due date.
2. The system records the initial assignment event.
3. Reassignment records old and new assignee/reviewer values, actor, timestamp, and optional reason.
4. The assignee updates progress; the reviewer can be notified or asked to review in a later workflow slice.
5. Completion of a work item does not automatically mark a tax obligation as filed or paid.

## 6. Required local tests

- Owner can assign a client to another active member in the same firm.
- Active ordinary members can read all clients and assignments in their firm, including clients assigned to someone else.
- A firm member cannot assign a client to a user who is not an active member of that firm.
- A client from another firm cannot be referenced by an assignment or work item.
- Only one active primary assignment can exist for a client.
- Closing and replacing an assignment preserves both history events.
- A task cannot have the same assignee and reviewer.
- A task cannot reference a membership from another firm.
- An assigned employee can update progress but cannot change the assignee/reviewer.
- A manager can reassign a task; history records old/new assignees and actor.
- An ordinary authenticated user cannot directly modify assignment history.
- A suspended membership cannot be newly assigned work.

## 7. Open implementation decisions

- Whether staff can create tasks for themselves or task creation remains manager-controlled in v1.
- Whether a work item can exist without a client (office administration tasks); this prototype requires a client.
- Whether supporting assignments need a start/end date entered manually or use system timestamps only.
- Whether reviewer is mandatory for selected task categories or obligation stages.
- Exact notification rules for assignment, reassignment, due-date changes, and review requests.
- Whether reassignment requires a reason for all changes or only selected high-risk task categories.

## 8. Explicit exclusions

This design does not implement tax obligation lifecycle, checklist execution, formal review decisions, ETA filing, email/SMS delivery, or production role administration. It does not authorize changes to hosted Supabase or any migration directory.
