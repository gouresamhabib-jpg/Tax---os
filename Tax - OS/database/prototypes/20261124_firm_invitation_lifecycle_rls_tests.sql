-- Local-only tests for 20261124_firm_invitation_lifecycle.sql.
-- Prerequisites: apply all three prototype SQL files in the documented order.
-- Requires three existing Auth users:
--   user_a = firm owner
--   user_b = second firm owner and invited firm member/admin
--   user_c = invitation recipient
-- Run only against disposable local PostgreSQL/Supabase and rollback fixtures.

\if :{?user_a}
\else
  \echo 'Missing -v user_a=<Auth UUID>'
  \quit
\endif
\if :{?user_b}
\else
  \echo 'Missing -v user_b=<Auth UUID>'
  \quit
\endif
\if :{?user_c}
\else
  \echo 'Missing -v user_c=<Auth UUID>'
  \quit
\endif

BEGIN;

-- Local Auth fixture: ensure all identities have deterministic, confirmed emails.
UPDATE auth.users SET email = 'taxos-user-a@example.com',
  email_confirmed_at = COALESCE(email_confirmed_at, now())
WHERE id = :'user_a'::uuid;
UPDATE auth.users SET email = 'taxos-user-b@example.com',
  email_confirmed_at = COALESCE(email_confirmed_at, now())
WHERE id = :'user_b'::uuid;
UPDATE auth.users SET email = 'taxos-user-c@example.com',
  email_confirmed_at = COALESCE(email_confirmed_at, now())
WHERE id = :'user_c'::uuid;

INSERT INTO taxos_prototype.firms (name, created_by)
VALUES ('Invitation Test Firm A', :'user_a'::uuid)
RETURNING id AS firm_a_id \gset

INSERT INTO taxos_prototype.firms (name, created_by)
VALUES ('Invitation Test Firm B', :'user_b'::uuid)
RETURNING id AS firm_b_id \gset

INSERT INTO taxos_prototype.firm_memberships (firm_id, user_id, role, status)
VALUES (:'firm_a_id'::uuid, :'user_b'::uuid, 'manager', 'active');

SELECT id AS owner_membership_id
FROM taxos_prototype.firm_memberships
WHERE firm_id = :'firm_a_id'::uuid AND user_id = :'user_a'::uuid
\gset
SELECT id AS manager_membership_id
FROM taxos_prototype.firm_memberships
WHERE firm_id = :'firm_a_id'::uuid AND user_id = :'user_b'::uuid
\gset

INSERT INTO taxos_prototype.clients (firm_id, client_type, display_name, created_by)
VALUES (:'firm_a_id'::uuid, 'company', 'Invitation Test Client', :'user_a'::uuid);

SELECT set_config('taxos_test.firm_a_id', :'firm_a_id', true);
SELECT set_config('taxos_test.firm_b_id', :'firm_b_id', true);
SELECT set_config('taxos_test.owner_membership_id', :'owner_membership_id', true);
SELECT set_config('taxos_test.manager_membership_id', :'manager_membership_id', true);
SELECT set_config('taxos_test.user_a', :'user_a', true);
SELECT set_config('taxos_test.user_b', :'user_b', true);
SELECT set_config('taxos_test.user_c', :'user_c', true);

-- Owner creates an invitation with a fixed seven-day expiry.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_a', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_a')::text, true);

SELECT taxos_prototype.create_firm_invitation(
  :'firm_a_id'::uuid, 'taxos-user-c@example.com', 'staff'
) AS invitation_id \gset
SELECT set_config('taxos_test.invitation_id', :'invitation_id', true);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM taxos_prototype.firm_invitations
    WHERE id = current_setting('taxos_test.invitation_id')::uuid
      AND status = 'pending' AND role = 'staff'
      AND expires_at > now() AND expires_at <= now() + interval '7 days' + interval '1 minute'
  ) THEN
    RAISE EXCEPTION 'Owner invitation was not created with expected status, role, and expiry';
  END IF;
END;
$$;

-- A manager cannot invite another member.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_b', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_b')::text, true);
DO $$
DECLARE
  rejected boolean := false;
BEGIN
  BEGIN
    PERFORM taxos_prototype.create_firm_invitation(
      current_setting('taxos_test.firm_a_id')::uuid,
      'another-person@example.com', 'accountant'
    );
  EXCEPTION WHEN raise_exception THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'Manager was allowed to invite a member'; END IF;
END;
$$;

-- An invited person can see their own invitation, but no unrelated invitation.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_c', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_c')::text, true);
DO $$
BEGIN
  IF (SELECT count(*) FROM taxos_prototype.firm_invitations
      WHERE id = current_setting('taxos_test.invitation_id')::uuid) <> 1 THEN
    RAISE EXCEPTION 'Invitee could not read their own invitation';
  END IF;
  IF (SELECT count(*) FROM taxos_prototype.firm_invitations
      WHERE firm_id = current_setting('taxos_test.firm_b_id')::uuid) <> 0 THEN
    RAISE EXCEPTION 'Invitee could read an unrelated firm invitation';
  END IF;
END;
$$;

-- A different confirmed email cannot accept the invitation.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_b', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_b')::text, true);
DO $$
DECLARE
  rejected boolean := false;
BEGIN
  BEGIN
    PERFORM taxos_prototype.accept_firm_invitation(
      current_setting('taxos_test.invitation_id')::uuid
    );
  EXCEPTION WHEN raise_exception THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'A different email accepted the invitation'; END IF;
END;
$$;

-- The matching confirmed email can accept once; acceptance creates active membership.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_c', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_c')::text, true);
SELECT taxos_prototype.accept_firm_invitation(
  current_setting('taxos_test.invitation_id')::uuid
) AS accepted_membership_id \gset
SELECT set_config('taxos_test.accepted_membership_id', :'accepted_membership_id', true);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM taxos_prototype.firm_memberships
    WHERE id = current_setting('taxos_test.accepted_membership_id')::uuid
      AND firm_id = current_setting('taxos_test.firm_a_id')::uuid
      AND user_id = current_setting('taxos_test.user_c')::uuid
      AND role = 'staff' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Invitation acceptance did not create the expected active membership';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM taxos_prototype.firm_invitations
    WHERE id = current_setting('taxos_test.invitation_id')::uuid
      AND status = 'accepted'
      AND accepted_by_user_id = current_setting('taxos_test.user_c')::uuid
  ) THEN
    RAISE EXCEPTION 'Invitation acceptance status was not recorded';
  END IF;
END;
$$;

-- The invitation cannot be accepted twice.
DO $$
DECLARE
  rejected boolean := false;
BEGIN
  BEGIN
    PERFORM taxos_prototype.accept_firm_invitation(
      current_setting('taxos_test.invitation_id')::uuid
    );
  EXCEPTION WHEN raise_exception THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'Accepted invitation was reusable'; END IF;
END;
$$;

-- Only the owner can promote an employee to admin.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_a', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_a')::text, true);
SELECT taxos_prototype.change_firm_member_role(
  current_setting('taxos_test.firm_a_id')::uuid,
  current_setting('taxos_test.manager_membership_id')::uuid,
  'admin'
);

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_b', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_b')::text, true);
DO $$
DECLARE
  rejected boolean := false;
BEGIN
  BEGIN
    PERFORM taxos_prototype.change_firm_member_role(
      current_setting('taxos_test.firm_a_id')::uuid,
      current_setting('taxos_test.accepted_membership_id')::uuid,
      'admin'
    );
  EXCEPTION WHEN raise_exception THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'Admin was allowed to appoint another admin'; END IF;
END;
$$;

-- Admin can manage ordinary member roles, but cannot manage their own role.
SELECT taxos_prototype.change_firm_member_role(
  current_setting('taxos_test.firm_a_id')::uuid,
  current_setting('taxos_test.accepted_membership_id')::uuid,
  'accountant'
);

-- Admin cannot suspend themselves.
DO $$
DECLARE
  rejected boolean := false;
BEGIN
  BEGIN
    PERFORM taxos_prototype.set_firm_member_status(
      current_setting('taxos_test.firm_a_id')::uuid,
      current_setting('taxos_test.manager_membership_id')::uuid,
      'suspended'
    );
  EXCEPTION WHEN raise_exception THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'Admin was allowed to suspend their own membership'; END IF;
END;
$$;

-- Owner cannot change or suspend the owner membership.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_a', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_a')::text, true);
DO $$
DECLARE
  role_rejected boolean := false;
  status_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM taxos_prototype.change_firm_member_role(
      current_setting('taxos_test.firm_a_id')::uuid,
      current_setting('taxos_test.owner_membership_id')::uuid,
      'accountant'
    );
  EXCEPTION WHEN raise_exception THEN role_rejected := true;
  END;
  BEGIN
    PERFORM taxos_prototype.set_firm_member_status(
      current_setting('taxos_test.firm_a_id')::uuid,
      current_setting('taxos_test.owner_membership_id')::uuid,
      'suspended'
    );
  EXCEPTION WHEN raise_exception THEN status_rejected := true;
  END;
  IF NOT role_rejected OR NOT status_rejected THEN
    RAISE EXCEPTION 'Owner membership was not protected from role/status changes';
  END IF;
END;
$$;

-- Suspend/re-activate/revoke membership and verify tenant RLS follows status.
SELECT taxos_prototype.set_firm_member_status(
  current_setting('taxos_test.firm_a_id')::uuid,
  current_setting('taxos_test.accepted_membership_id')::uuid,
  'suspended'
);

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_c', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_c')::text, true);
DO $$
BEGIN
  IF (SELECT count(*) FROM taxos_prototype.clients
      WHERE firm_id = current_setting('taxos_test.firm_a_id')::uuid) <> 0 THEN
    RAISE EXCEPTION 'Suspended member retained firm data access';
  END IF;
END;
$$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_a', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_a')::text, true);
SELECT taxos_prototype.set_firm_member_status(
  current_setting('taxos_test.firm_a_id')::uuid,
  current_setting('taxos_test.accepted_membership_id')::uuid,
  'active'
);
SELECT taxos_prototype.set_firm_member_status(
  current_setting('taxos_test.firm_a_id')::uuid,
  current_setting('taxos_test.accepted_membership_id')::uuid,
  'revoked'
);

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_c', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_c')::text, true);
DO $$
BEGIN
  IF (SELECT count(*) FROM taxos_prototype.clients
      WHERE firm_id = current_setting('taxos_test.firm_a_id')::uuid) <> 0 THEN
    RAISE EXCEPTION 'Revoked member retained firm data access';
  END IF;
END;
$$;

-- Revoked membership is terminal; it cannot be reactivated.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_a', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_a')::text, true);
DO $$
DECLARE
  rejected boolean := false;
BEGIN
  BEGIN
    PERFORM taxos_prototype.set_firm_member_status(
      current_setting('taxos_test.firm_a_id')::uuid,
      current_setting('taxos_test.accepted_membership_id')::uuid,
      'active'
    );
  EXCEPTION WHEN raise_exception THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'Revoked membership was reactivated'; END IF;
END;
$$;

-- Invitation revocation and expiry are terminal states.
SELECT taxos_prototype.create_firm_invitation(
  current_setting('taxos_test.firm_a_id')::uuid,
  'revoke-me@example.com', 'read_only'
) AS revoke_invitation_id \gset
SELECT set_config('taxos_test.revoke_invitation_id', :'revoke_invitation_id', true);
SELECT taxos_prototype.revoke_firm_invitation(
  current_setting('taxos_test.revoke_invitation_id')::uuid
);
DO $$
BEGIN
  IF (SELECT status FROM taxos_prototype.firm_invitations
      WHERE id = current_setting('taxos_test.revoke_invitation_id')::uuid) <> 'revoked' THEN
    RAISE EXCEPTION 'Invitation revocation was not recorded';
  END IF;
END;
$$;

SELECT taxos_prototype.create_firm_invitation(
  current_setting('taxos_test.firm_a_id')::uuid,
  'expires-me@example.com', 'read_only'
) AS expired_invitation_id \gset
SELECT set_config('taxos_test.expired_invitation_id', :'expired_invitation_id', true);
UPDATE taxos_prototype.firm_invitations
SET expires_at = now() - interval '1 minute'
WHERE id = current_setting('taxos_test.expired_invitation_id')::uuid;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_c', true);
SELECT set_config('request.jwt.claims', json_build_object('sub', :'user_c')::text, true);
SELECT taxos_prototype.accept_firm_invitation(
  current_setting('taxos_test.expired_invitation_id')::uuid
);
DO $$
BEGIN
  IF (SELECT status FROM taxos_prototype.firm_invitations
      WHERE id = current_setting('taxos_test.expired_invitation_id')::uuid) <> 'expired' THEN
    RAISE EXCEPTION 'Expired invitation state was not recorded';
  END IF;
END;
$$;

-- Membership/event history is readable only by firm owners/admins and is immutable.
DO $$
BEGIN
  IF has_table_privilege(current_user, 'taxos_prototype.firm_membership_events', 'UPDATE')
     OR has_table_privilege(current_user, 'taxos_prototype.firm_membership_events', 'DELETE') THEN
    RAISE EXCEPTION 'Authenticated role can mutate membership audit history';
  END IF;
END;
$$;

RESET ROLE;
ROLLBACK;

\echo 'TaxOS invitation and membership lifecycle checks completed; fixtures rolled back.'
