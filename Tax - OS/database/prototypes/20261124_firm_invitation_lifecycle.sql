-- TaxOS local prototype ONLY — invitation and membership lifecycle.
-- Apply after:
--   1. 20261124_firm_client_registry.sql
--   2. 20261124_client_assignments_and_work_items.sql
-- This is NOT a Supabase migration. Use only on a disposable local database.
--
-- Invitation email delivery is intentionally outside this SQL prototype.
-- The invitation UUID is an opaque link reference; acceptance additionally
-- requires an authenticated, email-confirmed user with the matching email.

BEGIN;

-- The helper exposes only the caller's confirmed email, not arbitrary auth.users rows.
CREATE OR REPLACE FUNCTION taxos_prototype.current_auth_email()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, auth
AS $$
  SELECT lower(email)
  FROM auth.users
  WHERE id = auth.uid()
    AND email_confirmed_at IS NOT NULL;
$$;

CREATE TABLE taxos_prototype.firm_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL REFERENCES taxos_prototype.firms(id) ON DELETE CASCADE,
  invited_email text NOT NULL CHECK (
    invited_email = lower(btrim(invited_email))
    AND invited_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  ),
  role text NOT NULL CHECK (
    role IN ('admin', 'manager', 'accountant', 'reviewer', 'staff', 'read_only')
  ),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'revoked', 'expired')),
  invited_by_membership_id uuid NOT NULL,
  accepted_by_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  accepted_membership_id uuid,
  expires_at timestamptz NOT NULL,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT firm_invitations_firm_id_id_unique UNIQUE (firm_id, id),
  CONSTRAINT firm_invitations_inviter_fk
    FOREIGN KEY (firm_id, invited_by_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT firm_invitations_accepted_membership_fk
    FOREIGN KEY (firm_id, accepted_membership_id)
    REFERENCES taxos_prototype.firm_memberships (firm_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT firm_invitations_acceptance_consistency CHECK (
    (status = 'accepted' AND accepted_by_user_id IS NOT NULL
      AND accepted_membership_id IS NOT NULL AND accepted_at IS NOT NULL)
    OR
    (status <> 'accepted' AND accepted_by_user_id IS NULL
      AND accepted_membership_id IS NULL AND accepted_at IS NULL)
  ),
  CONSTRAINT firm_invitations_revocation_consistency CHECK (
    (status = 'revoked' AND revoked_at IS NOT NULL)
    OR (status <> 'revoked' AND revoked_at IS NULL)
  )
);

CREATE UNIQUE INDEX firm_invitations_one_pending_email_idx
  ON taxos_prototype.firm_invitations (firm_id, invited_email)
  WHERE status = 'pending';

CREATE INDEX firm_invitations_firm_status_created_idx
  ON taxos_prototype.firm_invitations (firm_id, status, created_at DESC);

CREATE TABLE taxos_prototype.firm_membership_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL REFERENCES taxos_prototype.firms(id) ON DELETE CASCADE,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  target_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  invitation_id uuid,
  event_type text NOT NULL CHECK (
    event_type IN (
      'invitation_created', 'invitation_accepted', 'invitation_revoked', 'invitation_expired',
      'member_role_changed', 'member_suspended', 'member_reactivated',
      'member_revoked'
    )
  ),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT firm_membership_events_invitation_fk
    FOREIGN KEY (firm_id, invitation_id)
    REFERENCES taxos_prototype.firm_invitations (firm_id, id)
    ON DELETE RESTRICT
);

CREATE INDEX firm_membership_events_firm_created_idx
  ON taxos_prototype.firm_membership_events (firm_id, created_at DESC);

ALTER TABLE taxos_prototype.firm_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxos_prototype.firm_membership_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY invitations_select_manager_or_invitee
ON taxos_prototype.firm_invitations
FOR SELECT TO authenticated
USING (
  taxos_prototype.has_firm_role(firm_id, ARRAY['owner', 'admin'])
  OR invited_email = taxos_prototype.current_auth_email()
);

CREATE POLICY membership_events_select_admin
ON taxos_prototype.firm_membership_events
FOR SELECT TO authenticated
USING (taxos_prototype.has_firm_role(firm_id, ARRAY['owner', 'admin']));

-- ---------------------------------------------------------------------------
-- Invitation lifecycle
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION taxos_prototype.create_firm_invitation(
  p_firm_id uuid,
  p_email text,
  p_role text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
DECLARE
  v_email text := lower(btrim(p_email));
  v_actor_membership_id uuid;
  v_invitation_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM taxos_prototype.firms
    WHERE id = p_firm_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Firm is not active';
  END IF;

  IF NOT taxos_prototype.has_firm_role(p_firm_id, ARRAY['owner', 'admin']) THEN
    RAISE EXCEPTION 'Only firm owners and admins may invite members';
  END IF;

  IF p_role NOT IN ('admin', 'manager', 'accountant', 'reviewer', 'staff', 'read_only') THEN
    RAISE EXCEPTION 'Unsupported invitation role';
  END IF;

  IF p_role = 'admin'
     AND NOT taxos_prototype.has_firm_role(p_firm_id, ARRAY['owner']) THEN
    RAISE EXCEPTION 'Only the firm owner may invite an admin';
  END IF;

  IF v_email IS NULL OR v_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
    RAISE EXCEPTION 'A valid email address is required';
  END IF;

  IF EXISTS (
    SELECT 1 FROM taxos_prototype.firm_memberships m
    JOIN auth.users u ON u.id = m.user_id
    WHERE m.firm_id = p_firm_id AND lower(u.email) = v_email
  ) THEN
    RAISE EXCEPTION 'This email already has a membership in the firm';
  END IF;

  WITH expired AS (
    UPDATE taxos_prototype.firm_invitations
    SET status = 'expired'
    WHERE firm_id = p_firm_id
      AND invited_email = v_email
      AND status = 'pending'
      AND expires_at <= now()
    RETURNING id, invited_email
  )
  INSERT INTO taxos_prototype.firm_membership_events (
    firm_id, actor_user_id, invitation_id, event_type, details
  )
  SELECT p_firm_id, auth.uid(), id, 'invitation_expired',
    jsonb_build_object('email', invited_email, 'reason', 'expired_before_reinvite')
  FROM expired;

  SELECT id INTO v_actor_membership_id
  FROM taxos_prototype.firm_memberships
  WHERE firm_id = p_firm_id AND user_id = auth.uid() AND status = 'active';

  INSERT INTO taxos_prototype.firm_invitations (
    firm_id, invited_email, role, invited_by_membership_id,
    expires_at
  )
  VALUES (
    p_firm_id, v_email, p_role, v_actor_membership_id,
    now() + interval '7 days'
  )
  RETURNING id INTO v_invitation_id;

  INSERT INTO taxos_prototype.firm_membership_events (
    firm_id, actor_user_id, invitation_id, event_type, details
  )
  VALUES (
    p_firm_id, auth.uid(), v_invitation_id, 'invitation_created',
    jsonb_build_object('email', v_email, 'role', p_role, 'expires_at', now() + interval '7 days')
  );

  RETURN v_invitation_id;
END;
$$;

CREATE OR REPLACE FUNCTION taxos_prototype.accept_firm_invitation(
  p_invitation_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
DECLARE
  v_invitation taxos_prototype.firm_invitations%ROWTYPE;
  v_email text;
  v_confirmed_at timestamptz;
  v_membership_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT lower(email), email_confirmed_at
  INTO v_email, v_confirmed_at
  FROM auth.users
  WHERE id = auth.uid();

  IF v_email IS NULL OR v_confirmed_at IS NULL THEN
    RAISE EXCEPTION 'A confirmed email address is required';
  END IF;

  SELECT * INTO v_invitation
  FROM taxos_prototype.firm_invitations
  WHERE id = p_invitation_id
  FOR UPDATE;

  IF NOT FOUND OR v_invitation.status <> 'pending' THEN
    RAISE EXCEPTION 'Invitation is unavailable';
  END IF;

  IF v_invitation.expires_at <= now() THEN
    UPDATE taxos_prototype.firm_invitations
    SET status = 'expired'
    WHERE id = p_invitation_id;

    INSERT INTO taxos_prototype.firm_membership_events (
      firm_id, actor_user_id, invitation_id, event_type, details
    )
    VALUES (
      v_invitation.firm_id, auth.uid(), p_invitation_id,
      'invitation_expired', jsonb_build_object('email', v_invitation.invited_email)
    );
    RETURN NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM taxos_prototype.firms
    WHERE id = v_invitation.firm_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Firm is not active';
  END IF;

  IF v_invitation.invited_email <> v_email THEN
    RAISE EXCEPTION 'Sign in with the email address that received this invitation';
  END IF;

  IF EXISTS (
    SELECT 1 FROM taxos_prototype.firm_memberships
    WHERE firm_id = v_invitation.firm_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'This user already has a membership in the firm';
  END IF;

  INSERT INTO taxos_prototype.firm_memberships (firm_id, user_id, role, status)
  VALUES (v_invitation.firm_id, auth.uid(), v_invitation.role, 'active')
  RETURNING id INTO v_membership_id;

  UPDATE taxos_prototype.firm_invitations
  SET status = 'accepted',
      accepted_by_user_id = auth.uid(),
      accepted_membership_id = v_membership_id,
      accepted_at = now()
  WHERE id = p_invitation_id;

  INSERT INTO taxos_prototype.firm_membership_events (
    firm_id, actor_user_id, target_user_id, invitation_id, event_type, details
  )
  VALUES (
    v_invitation.firm_id, auth.uid(), auth.uid(), p_invitation_id,
    'invitation_accepted', jsonb_build_object('role', v_invitation.role)
  );

  RETURN v_membership_id;
END;
$$;

CREATE OR REPLACE FUNCTION taxos_prototype.revoke_firm_invitation(
  p_invitation_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
DECLARE
  v_invitation taxos_prototype.firm_invitations%ROWTYPE;
BEGIN
  SELECT * INTO v_invitation
  FROM taxos_prototype.firm_invitations
  WHERE id = p_invitation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation is unavailable';
  END IF;

  IF NOT taxos_prototype.has_firm_role(v_invitation.firm_id, ARRAY['owner', 'admin']) THEN
    RAISE EXCEPTION 'Only firm owners and admins may revoke invitations';
  END IF;

  IF v_invitation.status <> 'pending' THEN
    RAISE EXCEPTION 'Only pending invitations may be revoked';
  END IF;

  UPDATE taxos_prototype.firm_invitations
  SET status = 'revoked', revoked_at = now()
  WHERE id = p_invitation_id;

  INSERT INTO taxos_prototype.firm_membership_events (
    firm_id, actor_user_id, invitation_id, event_type, details
  )
  VALUES (
    v_invitation.firm_id, auth.uid(), p_invitation_id,
    'invitation_revoked', jsonb_build_object('email', v_invitation.invited_email)
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Role and membership status administration
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION taxos_prototype.change_firm_member_role(
  p_firm_id uuid,
  p_membership_id uuid,
  p_new_role text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
DECLARE
  v_target taxos_prototype.firm_memberships%ROWTYPE;
BEGIN
  IF NOT taxos_prototype.has_firm_role(p_firm_id, ARRAY['owner', 'admin']) THEN
    RAISE EXCEPTION 'Only firm owners and admins may change member roles';
  END IF;

  IF p_new_role NOT IN ('admin', 'manager', 'accountant', 'reviewer', 'staff', 'read_only') THEN
    RAISE EXCEPTION 'Unsupported membership role';
  END IF;

  SELECT * INTO v_target
  FROM taxos_prototype.firm_memberships
  WHERE firm_id = p_firm_id AND id = p_membership_id
  FOR UPDATE;

  IF NOT FOUND OR v_target.role = 'owner' THEN
    RAISE EXCEPTION 'Target membership cannot be changed';
  END IF;

  IF v_target.user_id = auth.uid() THEN
    RAISE EXCEPTION 'Members cannot change their own role';
  END IF;

  IF v_target.role = 'admin' OR p_new_role = 'admin' THEN
    IF NOT taxos_prototype.has_firm_role(p_firm_id, ARRAY['owner']) THEN
      RAISE EXCEPTION 'Only the firm owner may manage admin roles';
    END IF;
  END IF;

  IF v_target.status = 'revoked' THEN
    RAISE EXCEPTION 'Revoked membership is immutable';
  END IF;

  IF v_target.role = p_new_role THEN RETURN; END IF;

  UPDATE taxos_prototype.firm_memberships
  SET role = p_new_role
  WHERE id = p_membership_id;

  INSERT INTO taxos_prototype.firm_membership_events (
    firm_id, actor_user_id, target_user_id, event_type, details
  )
  VALUES (
    p_firm_id, auth.uid(), v_target.user_id, 'member_role_changed',
    jsonb_build_object('old_role', v_target.role, 'new_role', p_new_role)
  );
END;
$$;

CREATE OR REPLACE FUNCTION taxos_prototype.set_firm_member_status(
  p_firm_id uuid,
  p_membership_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
DECLARE
  v_target taxos_prototype.firm_memberships%ROWTYPE;
  v_event text;
BEGIN
  IF NOT taxos_prototype.has_firm_role(p_firm_id, ARRAY['owner', 'admin']) THEN
    RAISE EXCEPTION 'Only firm owners and admins may change membership status';
  END IF;

  IF p_new_status NOT IN ('active', 'suspended', 'revoked') THEN
    RAISE EXCEPTION 'Unsupported membership status';
  END IF;

  SELECT * INTO v_target
  FROM taxos_prototype.firm_memberships
  WHERE firm_id = p_firm_id AND id = p_membership_id
  FOR UPDATE;

  IF NOT FOUND OR v_target.role = 'owner' THEN
    RAISE EXCEPTION 'Target membership cannot be changed';
  END IF;

  IF v_target.user_id = auth.uid() THEN
    RAISE EXCEPTION 'Members cannot change their own membership status';
  END IF;

  IF v_target.role = 'admin'
     AND NOT taxos_prototype.has_firm_role(p_firm_id, ARRAY['owner']) THEN
    RAISE EXCEPTION 'Only the firm owner may manage admin memberships';
  END IF;

  IF v_target.status = 'revoked' THEN
    RAISE EXCEPTION 'Revoked membership is immutable';
  END IF;

  IF p_new_status = v_target.status THEN RETURN; END IF;

  IF p_new_status = 'active' AND v_target.status <> 'suspended' THEN
    RAISE EXCEPTION 'Only suspended memberships may be reactivated';
  END IF;

  UPDATE taxos_prototype.firm_memberships
  SET status = p_new_status
  WHERE id = p_membership_id;

  v_event := CASE p_new_status
    WHEN 'suspended' THEN 'member_suspended'
    WHEN 'active' THEN 'member_reactivated'
    ELSE 'member_revoked'
  END;

  INSERT INTO taxos_prototype.firm_membership_events (
    firm_id, actor_user_id, target_user_id, event_type, details
  )
  VALUES (
    p_firm_id, auth.uid(), v_target.user_id, v_event,
    jsonb_build_object('old_status', v_target.status, 'new_status', p_new_status)
  );
END;
$$;

-- No authenticated direct writes to memberships, invitations, or event history.
REVOKE INSERT, UPDATE, DELETE ON taxos_prototype.firm_memberships FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON taxos_prototype.firm_invitations FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON taxos_prototype.firm_membership_events FROM authenticated;
GRANT SELECT ON taxos_prototype.firm_invitations TO authenticated;
GRANT SELECT ON taxos_prototype.firm_membership_events TO authenticated;

REVOKE ALL ON FUNCTION taxos_prototype.current_auth_email() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION taxos_prototype.create_firm_invitation(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION taxos_prototype.accept_firm_invitation(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION taxos_prototype.revoke_firm_invitation(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION taxos_prototype.change_firm_member_role(uuid, uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION taxos_prototype.set_firm_member_status(uuid, uuid, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION taxos_prototype.current_auth_email() TO authenticated;
GRANT EXECUTE ON FUNCTION taxos_prototype.create_firm_invitation(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION taxos_prototype.accept_firm_invitation(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION taxos_prototype.revoke_firm_invitation(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION taxos_prototype.change_firm_member_role(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION taxos_prototype.set_firm_member_status(uuid, uuid, text) TO authenticated;

COMMENT ON TABLE taxos_prototype.firm_invitations IS
  'Local prototype invitation lifecycle. Delivery is a separate trusted backend responsibility; acceptance requires matching confirmed Auth email.';
COMMENT ON TABLE taxos_prototype.firm_membership_events IS
  'Append-only audit events for invitation and membership administration.';

COMMIT;
