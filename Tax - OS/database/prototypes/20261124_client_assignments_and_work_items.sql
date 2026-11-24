-- TaxOS local prototype extension ONLY — not a Supabase migration.
-- Prerequisite: 20261124_firm_client_registry.sql has been run on a disposable
-- local Supabase/PostgreSQL database.
-- Adds client responsibility, work items, and append-only assignment history.
-- Does not modify public.*, legacy tables, hosted Supabase, or migration history.

-- ---------------------------------------------------------------------------
-- Membership validation helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION taxos_prototype.is_active_firm_membership(
  p_firm_id uuid,
  p_membership_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM taxos_prototype.firm_memberships AS membership
    WHERE membership.firm_id = p_firm_id
      AND membership.id = p_membership_id
      AND membership.status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION taxos_prototype.is_firm_manager(p_firm_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
  SELECT taxos_prototype.has_firm_role(
    p_firm_id,
    ARRAY['owner', 'admin', 'manager']
  );
$$;

REVOKE ALL ON FUNCTION taxos_prototype.is_active_firm_membership(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION taxos_prototype.is_firm_manager(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION taxos_prototype.is_active_firm_membership(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION taxos_prototype.is_firm_manager(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Client assignments
-- ---------------------------------------------------------------------------

CREATE TABLE taxos_prototype.client_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  client_id uuid NOT NULL,
  member_id uuid NOT NULL,
  assignment_role text NOT NULL
    CHECK (assignment_role IN ('primary', 'supporting')),
  assigned_by_membership_id uuid NOT NULL,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  ended_by_membership_id uuid,
  ended_at timestamptz,
  end_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT client_assignments_client_fk
    FOREIGN KEY (firm_id, client_id)
    REFERENCES taxos_prototype.clients (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT client_assignments_member_fk
    FOREIGN KEY (firm_id, member_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT client_assignments_assigned_by_fk
    FOREIGN KEY (firm_id, assigned_by_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT client_assignments_ended_by_fk
    FOREIGN KEY (firm_id, ended_by_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT client_assignments_end_pair_check
    CHECK (
      (ended_at IS NULL AND ended_by_membership_id IS NULL)
      OR (ended_at IS NOT NULL AND ended_by_membership_id IS NOT NULL)
    ),
  CONSTRAINT client_assignments_firm_id_id_unique UNIQUE (firm_id, id)
);

CREATE UNIQUE INDEX client_assignments_one_active_primary_idx
  ON taxos_prototype.client_assignments (firm_id, client_id)
  WHERE assignment_role = 'primary' AND ended_at IS NULL;

CREATE UNIQUE INDEX client_assignments_one_active_role_per_member_idx
  ON taxos_prototype.client_assignments (firm_id, client_id, member_id, assignment_role)
  WHERE ended_at IS NULL;

CREATE INDEX client_assignments_member_active_idx
  ON taxos_prototype.client_assignments (firm_id, member_id, client_id)
  WHERE ended_at IS NULL;

CREATE TABLE taxos_prototype.client_assignment_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  client_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('assigned', 'ended')),
  member_id uuid NOT NULL,
  performed_by_membership_id uuid NOT NULL,
  event_at timestamptz NOT NULL DEFAULT now(),
  reason text,
  CONSTRAINT client_assignment_events_client_fk
    FOREIGN KEY (firm_id, client_id)
    REFERENCES taxos_prototype.clients (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT client_assignment_events_assignment_fk
    FOREIGN KEY (firm_id, assignment_id)
    REFERENCES taxos_prototype.client_assignments (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT client_assignment_events_member_fk
    FOREIGN KEY (firm_id, member_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT client_assignment_events_actor_fk
    FOREIGN KEY (firm_id, performed_by_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT
);

CREATE INDEX client_assignment_events_client_time_idx
  ON taxos_prototype.client_assignment_events (firm_id, client_id, event_at DESC);

CREATE OR REPLACE FUNCTION taxos_prototype.validate_client_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
BEGIN
  IF NOT taxos_prototype.is_active_firm_member(NEW.firm_id) THEN
    RAISE EXCEPTION 'Caller is not an active member of this firm'
      USING ERRCODE = '42501';
  END IF;

  IF NOT taxos_prototype.is_firm_manager(NEW.firm_id) THEN
    RAISE EXCEPTION 'Only owner, admin, or manager may change client assignments'
      USING ERRCODE = '42501';
  END IF;

  IF NOT taxos_prototype.is_active_firm_membership(NEW.firm_id, NEW.member_id)
     OR NOT taxos_prototype.is_active_firm_membership(NEW.firm_id, NEW.assigned_by_membership_id) THEN
    RAISE EXCEPTION 'Assignee and assigning actor must be active members of this firm'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.ended_by_membership_id IS NOT NULL
     AND NOT taxos_prototype.is_active_firm_membership(NEW.firm_id, NEW.ended_by_membership_id) THEN
    RAISE EXCEPTION 'Ending actor must be an active member of this firm'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1 FROM taxos_prototype.clients AS client
    WHERE client.firm_id = NEW.firm_id
      AND client.id = NEW.client_id
      AND client.archived_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Archived clients cannot be assigned'
      USING ERRCODE = '23514';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.firm_id <> NEW.firm_id
       OR OLD.client_id <> NEW.client_id
       OR OLD.member_id <> NEW.member_id
       OR OLD.assignment_role <> NEW.assignment_role
       OR OLD.assigned_by_membership_id <> NEW.assigned_by_membership_id
       OR OLD.assigned_at <> NEW.assigned_at THEN
      RAISE EXCEPTION 'Assignment identity is immutable; close it and create a new assignment'
        USING ERRCODE = '23514';
    END IF;
    IF OLD.ended_at IS NOT NULL THEN
      RAISE EXCEPTION 'A closed assignment cannot be changed'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER client_assignments_validate
BEFORE INSERT OR UPDATE ON taxos_prototype.client_assignments
FOR EACH ROW EXECUTE FUNCTION taxos_prototype.validate_client_assignment();

CREATE OR REPLACE FUNCTION taxos_prototype.write_client_assignment_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO taxos_prototype.client_assignment_events (
      firm_id, client_id, assignment_id, event_type, member_id,
      performed_by_membership_id, event_at, reason
    )
    VALUES (
      NEW.firm_id, NEW.client_id, NEW.id, 'assigned', NEW.member_id,
      NEW.assigned_by_membership_id, NEW.assigned_at, NULL
    );
  ELSIF OLD.ended_at IS NULL AND NEW.ended_at IS NOT NULL THEN
    INSERT INTO taxos_prototype.client_assignment_events (
      firm_id, client_id, assignment_id, event_type, member_id,
      performed_by_membership_id, event_at, reason
    )
    VALUES (
      NEW.firm_id, NEW.client_id, NEW.id, 'ended', NEW.member_id,
      NEW.ended_by_membership_id, NEW.ended_at, NEW.end_reason
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER client_assignments_write_history
AFTER INSERT OR UPDATE ON taxos_prototype.client_assignments
FOR EACH ROW EXECUTE FUNCTION taxos_prototype.write_client_assignment_event();

-- ---------------------------------------------------------------------------
-- Work items and task assignment history
-- ---------------------------------------------------------------------------

CREATE TABLE taxos_prototype.work_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  client_id uuid NOT NULL,
  title text NOT NULL CHECK (length(btrim(title)) > 0),
  description text,
  status text NOT NULL DEFAULT 'todo'
    CHECK (status IN ('todo', 'in_progress', 'blocked', 'completed', 'cancelled')),
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  assignee_membership_id uuid NOT NULL,
  reviewer_membership_id uuid,
  created_by_membership_id uuid NOT NULL,
  updated_by_membership_id uuid NOT NULL,
  due_at timestamptz,
  completed_at timestamptz,
  archived_at timestamptz,
  assignment_change_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT work_items_client_fk
    FOREIGN KEY (firm_id, client_id)
    REFERENCES taxos_prototype.clients (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT work_items_assignee_fk
    FOREIGN KEY (firm_id, assignee_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT work_items_reviewer_fk
    FOREIGN KEY (firm_id, reviewer_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT work_items_creator_fk
    FOREIGN KEY (firm_id, created_by_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT work_items_updater_fk
    FOREIGN KEY (firm_id, updated_by_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT work_items_distinct_assignee_reviewer_check
    CHECK (reviewer_membership_id IS NULL OR reviewer_membership_id <> assignee_membership_id),
  CONSTRAINT work_items_firm_id_id_unique UNIQUE (firm_id, id)
);

CREATE INDEX work_items_assignee_queue_idx
  ON taxos_prototype.work_items (firm_id, assignee_membership_id, status, due_at)
  WHERE archived_at IS NULL;

CREATE INDEX work_items_client_status_idx
  ON taxos_prototype.work_items (firm_id, client_id, status)
  WHERE archived_at IS NULL;

CREATE TABLE taxos_prototype.work_item_assignment_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  work_item_id uuid NOT NULL,
  event_type text NOT NULL
    CHECK (event_type IN ('created', 'assignee_changed', 'reviewer_changed', 'assignee_and_reviewer_changed')),
  previous_assignee_membership_id uuid,
  new_assignee_membership_id uuid NOT NULL,
  previous_reviewer_membership_id uuid,
  new_reviewer_membership_id uuid,
  performed_by_membership_id uuid NOT NULL,
  event_at timestamptz NOT NULL DEFAULT now(),
  reason text,
  CONSTRAINT work_item_assignment_events_work_item_fk
    FOREIGN KEY (firm_id, work_item_id)
    REFERENCES taxos_prototype.work_items (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT work_item_assignment_events_previous_assignee_fk
    FOREIGN KEY (firm_id, previous_assignee_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT work_item_assignment_events_new_assignee_fk
    FOREIGN KEY (firm_id, new_assignee_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT work_item_assignment_events_previous_reviewer_fk
    FOREIGN KEY (firm_id, previous_reviewer_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT work_item_assignment_events_new_reviewer_fk
    FOREIGN KEY (firm_id, new_reviewer_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT work_item_assignment_events_actor_fk
    FOREIGN KEY (firm_id, performed_by_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT
);

CREATE INDEX work_item_assignment_events_item_time_idx
  ON taxos_prototype.work_item_assignment_events (firm_id, work_item_id, event_at DESC);

CREATE OR REPLACE FUNCTION taxos_prototype.validate_work_item()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
DECLARE
  assignment_changed boolean;
BEGIN
  IF NOT taxos_prototype.is_active_firm_member(NEW.firm_id) THEN
    RAISE EXCEPTION 'Caller is not an active member of this firm'
      USING ERRCODE = '42501';
  END IF;

  IF NOT taxos_prototype.is_active_firm_membership(NEW.firm_id, NEW.assignee_membership_id)
     OR NOT taxos_prototype.is_active_firm_membership(NEW.firm_id, NEW.created_by_membership_id)
     OR NOT taxos_prototype.is_active_firm_membership(NEW.firm_id, NEW.updated_by_membership_id) THEN
    RAISE EXCEPTION 'Assignee, creator, and updater must be active firm members'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.reviewer_membership_id IS NOT NULL
     AND NOT taxos_prototype.is_active_firm_membership(NEW.firm_id, NEW.reviewer_membership_id) THEN
    RAISE EXCEPTION 'Reviewer must be an active member of this firm'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1 FROM taxos_prototype.clients AS client
    WHERE client.firm_id = NEW.firm_id
      AND client.id = NEW.client_id
      AND client.archived_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Archived clients cannot receive new work items'
      USING ERRCODE = '23514';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NOT taxos_prototype.is_firm_manager(NEW.firm_id) THEN
      RAISE EXCEPTION 'Only owner, admin, or manager may create and assign work items'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.firm_id <> NEW.firm_id OR OLD.client_id <> NEW.client_id
     OR OLD.created_by_membership_id <> NEW.created_by_membership_id
     OR OLD.created_at <> NEW.created_at THEN
    RAISE EXCEPTION 'Work item tenant, client, creator, and creation time are immutable'
      USING ERRCODE = '23514';
  END IF;

  assignment_changed :=
    OLD.assignee_membership_id IS DISTINCT FROM NEW.assignee_membership_id
    OR OLD.reviewer_membership_id IS DISTINCT FROM NEW.reviewer_membership_id;

  IF assignment_changed AND NOT taxos_prototype.is_firm_manager(NEW.firm_id) THEN
    RAISE EXCEPTION 'Only owner, admin, or manager may change task assignments'
      USING ERRCODE = '42501';
  END IF;

  IF NOT taxos_prototype.is_firm_manager(NEW.firm_id)
     AND OLD.assignee_membership_id <> (
       SELECT membership.id
       FROM taxos_prototype.firm_memberships AS membership
       WHERE membership.firm_id = NEW.firm_id
         AND membership.user_id = auth.uid()
         AND membership.status = 'active'
     )
     AND OLD.reviewer_membership_id IS DISTINCT FROM (
       SELECT membership.id
       FROM taxos_prototype.firm_memberships AS membership
       WHERE membership.firm_id = NEW.firm_id
         AND membership.user_id = auth.uid()
         AND membership.status = 'active'
     ) THEN
    RAISE EXCEPTION 'Only the assignee, reviewer, or a manager may update this work item'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER work_items_validate
BEFORE INSERT OR UPDATE ON taxos_prototype.work_items
FOR EACH ROW EXECUTE FUNCTION taxos_prototype.validate_work_item();

CREATE OR REPLACE FUNCTION taxos_prototype.write_work_item_assignment_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
DECLARE
  event_kind text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    event_kind := 'created';
  ELSIF OLD.assignee_membership_id IS DISTINCT FROM NEW.assignee_membership_id
     AND OLD.reviewer_membership_id IS DISTINCT FROM NEW.reviewer_membership_id THEN
    event_kind := 'assignee_and_reviewer_changed';
  ELSIF OLD.assignee_membership_id IS DISTINCT FROM NEW.assignee_membership_id THEN
    event_kind := 'assignee_changed';
  ELSIF OLD.reviewer_membership_id IS DISTINCT FROM NEW.reviewer_membership_id THEN
    event_kind := 'reviewer_changed';
  ELSE
    RETURN NEW;
  END IF;

  INSERT INTO taxos_prototype.work_item_assignment_events (
    firm_id, work_item_id, event_type,
    previous_assignee_membership_id, new_assignee_membership_id,
    previous_reviewer_membership_id, new_reviewer_membership_id,
    performed_by_membership_id, reason
  )
  VALUES (
    NEW.firm_id, NEW.id, event_kind,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE OLD.assignee_membership_id END,
    NEW.assignee_membership_id,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE OLD.reviewer_membership_id END,
    NEW.reviewer_membership_id,
    NEW.updated_by_membership_id,
    NEW.assignment_change_reason
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER work_items_write_assignment_history
AFTER INSERT OR UPDATE ON taxos_prototype.work_items
FOR EACH ROW EXECUTE FUNCTION taxos_prototype.write_work_item_assignment_event();

CREATE TRIGGER work_items_updated_at
BEFORE UPDATE ON taxos_prototype.work_items
FOR EACH ROW EXECUTE FUNCTION taxos_prototype.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row-level security and privileges
-- ---------------------------------------------------------------------------

ALTER TABLE taxos_prototype.client_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxos_prototype.client_assignment_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxos_prototype.work_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxos_prototype.work_item_assignment_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY client_assignments_select_member ON taxos_prototype.client_assignments
FOR SELECT TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY client_assignments_insert_manager ON taxos_prototype.client_assignments
FOR INSERT TO authenticated
WITH CHECK (
  taxos_prototype.is_active_firm_member(firm_id)
  AND taxos_prototype.is_firm_manager(firm_id)
);

CREATE POLICY client_assignments_update_manager ON taxos_prototype.client_assignments
FOR UPDATE TO authenticated
USING (
  taxos_prototype.is_active_firm_member(firm_id)
  AND taxos_prototype.is_firm_manager(firm_id)
)
WITH CHECK (
  taxos_prototype.is_active_firm_member(firm_id)
  AND taxos_prototype.is_firm_manager(firm_id)
);

CREATE POLICY client_assignment_events_select_member ON taxos_prototype.client_assignment_events
FOR SELECT TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY work_items_select_member ON taxos_prototype.work_items
FOR SELECT TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY work_items_insert_manager ON taxos_prototype.work_items
FOR INSERT TO authenticated
WITH CHECK (
  taxos_prototype.is_active_firm_member(firm_id)
  AND taxos_prototype.is_firm_manager(firm_id)
);

CREATE POLICY work_items_update_manager_or_assignee ON taxos_prototype.work_items
FOR UPDATE TO authenticated
USING (
  taxos_prototype.is_active_firm_member(firm_id)
  AND (
    taxos_prototype.is_firm_manager(firm_id)
    OR assignee_membership_id IN (
      SELECT membership.id FROM taxos_prototype.firm_memberships AS membership
      WHERE membership.firm_id = work_items.firm_id
        AND membership.user_id = auth.uid()
        AND membership.status = 'active'
    )
    OR reviewer_membership_id IN (
      SELECT membership.id FROM taxos_prototype.firm_memberships AS membership
      WHERE membership.firm_id = work_items.firm_id
        AND membership.user_id = auth.uid()
        AND membership.status = 'active'
    )
  )
)
WITH CHECK (
  taxos_prototype.is_active_firm_member(firm_id)
);

CREATE POLICY work_item_assignment_events_select_member ON taxos_prototype.work_item_assignment_events
FOR SELECT TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

GRANT USAGE ON SCHEMA taxos_prototype TO authenticated;

GRANT SELECT, INSERT, UPDATE ON taxos_prototype.client_assignments TO authenticated;
REVOKE DELETE ON taxos_prototype.client_assignments FROM authenticated;

GRANT SELECT ON taxos_prototype.client_assignment_events TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON taxos_prototype.client_assignment_events FROM authenticated;

GRANT SELECT, INSERT ON taxos_prototype.work_items TO authenticated;
GRANT UPDATE (
  title, description, status, priority, assignee_membership_id,
  reviewer_membership_id, updated_by_membership_id, due_at,
  completed_at, archived_at, assignment_change_reason
) ON taxos_prototype.work_items TO authenticated;
REVOKE DELETE ON taxos_prototype.work_items FROM authenticated;

GRANT SELECT ON taxos_prototype.work_item_assignment_events TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON taxos_prototype.work_item_assignment_events FROM authenticated;

COMMENT ON TABLE taxos_prototype.client_assignments IS
  'Firm-scoped client responsibility periods; assignment does not restrict office-wide client visibility.';
COMMENT ON TABLE taxos_prototype.work_items IS
  'Firm-scoped operational tasks; separate from tax obligation status and filing/payment events.';
COMMENT ON TABLE taxos_prototype.client_assignment_events IS
  'Append-only client responsibility history written by database triggers.';
COMMENT ON TABLE taxos_prototype.work_item_assignment_events IS
  'Append-only task assignee/reviewer history written by database triggers.';
