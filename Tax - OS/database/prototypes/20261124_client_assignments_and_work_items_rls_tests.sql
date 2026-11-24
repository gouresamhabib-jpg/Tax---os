-- Local-only integration checks for 20261124_client_assignments_and_work_items.sql.
-- Prerequisites:
--   1. Run 20261124_firm_client_registry.sql.
--   2. Run 20261124_client_assignments_and_work_items.sql.
--   3. Supply two existing local Supabase Auth users:
--      psql ... -v user_a='UUID' -v user_b='UUID' -f this_file.sql
-- This script rolls back all fixtures and must run only on a disposable DB.

\if :{?user_a}
\else
  \echo 'Missing -v user_a=<existing auth.users UUID>'
  \quit
\endif
\if :{?user_b}
\else
  \echo 'Missing -v user_b=<existing auth.users UUID>'
  \quit
\endif

BEGIN;

INSERT INTO taxos_prototype.firms (name, created_by)
VALUES ('Assignment Test Firm A', :'user_a'::uuid)
RETURNING id AS firm_a_id \gset

INSERT INTO taxos_prototype.firms (name, created_by)
VALUES ('Assignment Test Firm B', :'user_b'::uuid)
RETURNING id AS firm_b_id \gset

INSERT INTO taxos_prototype.firm_memberships (firm_id, user_id, role, status)
VALUES (:'firm_a_id'::uuid, :'user_b'::uuid, 'accountant', 'active');

SELECT id AS member_a_id
FROM taxos_prototype.firm_memberships
WHERE firm_id = :'firm_a_id'::uuid AND user_id = :'user_a'::uuid
\gset

SELECT id AS member_b_id
FROM taxos_prototype.firm_memberships
WHERE firm_id = :'firm_a_id'::uuid AND user_id = :'user_b'::uuid
\gset

SELECT id AS member_b_firm_b_id
FROM taxos_prototype.firm_memberships
WHERE firm_id = :'firm_b_id'::uuid AND user_id = :'user_b'::uuid
\gset

INSERT INTO taxos_prototype.clients (firm_id, client_type, display_name, created_by)
VALUES (:'firm_a_id'::uuid, 'company', 'Assignment Test Client', :'user_a'::uuid)
RETURNING id AS client_a_id \gset

INSERT INTO taxos_prototype.clients (firm_id, client_type, display_name, created_by)
VALUES (:'firm_b_id'::uuid, 'company', 'Other Firm Client', :'user_b'::uuid)
RETURNING id AS client_b_id \gset

SELECT set_config('taxos_test.firm_a_id', :'firm_a_id', true);
SELECT set_config('taxos_test.firm_b_id', :'firm_b_id', true);
SELECT set_config('taxos_test.member_a_id', :'member_a_id', true);
SELECT set_config('taxos_test.member_b_id', :'member_b_id', true);
SELECT set_config('taxos_test.client_a_id', :'client_a_id', true);
SELECT set_config('taxos_test.client_b_id', :'client_b_id', true);
SELECT set_config('taxos_test.member_b_firm_b_id', :'member_b_firm_b_id', true);

-- Owner A assigns Client A to active employee B.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_a', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_a')::text, true);

INSERT INTO taxos_prototype.client_assignments (
  firm_id, client_id, member_id, assignment_role, assigned_by_membership_id
)
VALUES (
  :'firm_a_id'::uuid, :'client_a_id'::uuid, :'member_b_id'::uuid, 'primary', :'member_a_id'::uuid
)
RETURNING id AS client_assignment_id \gset
SELECT set_config('taxos_test.client_assignment_id', :'client_assignment_id', true);

-- Duplicate active primary responsibility is rejected.
DO $$
BEGIN
  BEGIN
    INSERT INTO taxos_prototype.client_assignments (
      firm_id, client_id, member_id, assignment_role, assigned_by_membership_id
    )
    VALUES (
      current_setting('taxos_test.firm_a_id')::uuid,
      current_setting('taxos_test.client_a_id')::uuid,
      current_setting('taxos_test.member_a_id')::uuid,
      'primary',
      current_setting('taxos_test.member_a_id')::uuid
    );
    RAISE EXCEPTION 'A second active primary client assignment was allowed';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END;
$$;

-- Cross-firm membership cannot be attached to a Firm A client.
DO $$
BEGIN
  BEGIN
    INSERT INTO taxos_prototype.client_assignments (
      firm_id, client_id, member_id, assignment_role, assigned_by_membership_id
    )
    VALUES (
      current_setting('taxos_test.firm_a_id')::uuid,
      current_setting('taxos_test.client_a_id')::uuid,
      current_setting('taxos_test.member_b_firm_b_id')::uuid,
      'supporting',
      current_setting('taxos_test.member_a_id')::uuid
    );
    RAISE EXCEPTION 'Cross-firm membership assignment was allowed';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
END;
$$;

INSERT INTO taxos_prototype.work_items (
  firm_id, client_id, title, assignee_membership_id,
  reviewer_membership_id, created_by_membership_id, updated_by_membership_id
)
VALUES (
  :'firm_a_id'::uuid, :'client_a_id'::uuid, 'Prepare VAT return',
  :'member_b_id'::uuid, :'member_a_id'::uuid, :'member_a_id'::uuid, :'member_a_id'::uuid
)
RETURNING id AS work_item_id \gset
SELECT set_config('taxos_test.work_item_id', :'work_item_id', true);

-- A task cannot be assigned to the same person who reviews it.
DO $$
BEGIN
  BEGIN
    INSERT INTO taxos_prototype.work_items (
      firm_id, client_id, title, assignee_membership_id,
      reviewer_membership_id, created_by_membership_id, updated_by_membership_id
    )
    VALUES (
      current_setting('taxos_test.firm_a_id')::uuid,
      current_setting('taxos_test.client_a_id')::uuid,
      'Invalid self-review task',
      current_setting('taxos_test.member_b_id')::uuid,
      current_setting('taxos_test.member_b_id')::uuid,
      current_setting('taxos_test.member_a_id')::uuid,
      current_setting('taxos_test.member_a_id')::uuid
    );
    RAISE EXCEPTION 'A task with identical assignee and reviewer was allowed';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END;
$$;

-- Reassign client responsibility. The old assignment is closed, not deleted.
UPDATE taxos_prototype.client_assignments
SET ended_at = now(),
    ended_by_membership_id = :'member_a_id'::uuid,
    end_reason = 'Workload reallocation'
WHERE id = :'client_assignment_id'::uuid;

INSERT INTO taxos_prototype.client_assignments (
  firm_id, client_id, member_id, assignment_role, assigned_by_membership_id
)
VALUES (
  :'firm_a_id'::uuid, :'client_a_id'::uuid, :'member_a_id'::uuid, 'primary', :'member_a_id'::uuid
);

-- Verify history was generated by database triggers.
DO $
BEGIN
  IF (SELECT count(*) FROM taxos_prototype.client_assignment_events
      WHERE firm_id = current_setting('taxos_test.firm_a_id')::uuid) <> 3 THEN
    RAISE EXCEPTION 'Expected assignment, ended, and reassignment history events';
  END IF;
  IF (SELECT count(*) FROM taxos_prototype.work_item_assignment_events
      WHERE firm_id = current_setting('taxos_test.firm_a_id')::uuid
        AND event_type = 'created') <> 1 THEN
    RAISE EXCEPTION 'Expected one task assignment history event';
  END IF;
END;
$$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_b', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_b')::text, true);

-- Ordinary active employee can still see every client and assignment in the firm.
DO $$
BEGIN
  IF (SELECT count(*) FROM taxos_prototype.clients
      WHERE firm_id = current_setting('taxos_test.firm_a_id')::uuid) <> 1 THEN
    RAISE EXCEPTION 'Office-wide client visibility failed for an ordinary active member';
  END IF;
  IF (SELECT count(*) FROM taxos_prototype.client_assignments
      WHERE firm_id = current_setting('taxos_test.firm_a_id')::uuid) <> 2 THEN
    RAISE EXCEPTION 'Office-wide assignment history visibility failed';
  END IF;
  IF (SELECT count(*) FROM taxos_prototype.client_assignments
      WHERE firm_id = current_setting('taxos_test.firm_a_id')::uuid
        AND ended_at IS NULL
        AND assignment_role = 'primary') <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one current primary client assignment';
  END IF;
  IF (SELECT count(*) FROM taxos_prototype.work_items
      WHERE firm_id = current_setting('taxos_test.firm_a_id')::uuid) <> 1 THEN
    RAISE EXCEPTION 'Office-wide task visibility failed';
  END IF;
END;
$$;

-- Assigned employee can update progress.
UPDATE taxos_prototype.work_items
SET status = 'in_progress',
    updated_by_membership_id = :'member_b_id'::uuid
WHERE id = current_setting('taxos_test.work_item_id')::uuid;

-- Assigned employee cannot reassign the task.
DO $$
BEGIN
  BEGIN
    UPDATE taxos_prototype.work_items
    SET assignee_membership_id = current_setting('taxos_test.member_a_id')::uuid,
        updated_by_membership_id = current_setting('taxos_test.member_b_id')::uuid
    WHERE id = current_setting('taxos_test.work_item_id')::uuid;
    RAISE EXCEPTION 'An ordinary assignee was allowed to reassign a task';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;

-- Authenticated clients cannot directly alter immutable assignment history.
DO $$
BEGIN
  IF has_table_privilege(current_user, 'taxos_prototype.work_item_assignment_events', 'UPDATE')
     OR has_table_privilege(current_user, 'taxos_prototype.client_assignment_events', 'DELETE') THEN
    RAISE EXCEPTION 'Authenticated role has direct history mutation privileges';
  END IF;
END;
$$;

RESET ROLE;
ROLLBACK;

\echo 'TaxOS assignment/work-item prototype checks completed; fixture transaction rolled back.'
