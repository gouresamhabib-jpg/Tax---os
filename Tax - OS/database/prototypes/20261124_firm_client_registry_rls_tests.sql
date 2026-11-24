-- Local-only integration checks for 20261124_firm_client_registry.sql.
-- Prerequisite: run the prototype schema first on a disposable local Supabase DB.
-- Create two test Auth users, then replace the two UUID placeholders below.
-- Example: psql ... -v user_a='...' -v user_b='...' -f this_file.sql
-- This script rolls back all fixture rows at the end.

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
VALUES ('Local Test Firm A', current_setting('taxos_test.user_a')::uuid)
RETURNING id AS firm_a_id \gset

INSERT INTO taxos_prototype.firms (name, created_by)
VALUES ('Local Test Firm B', current_setting('taxos_test.user_b')::uuid)
RETURNING id AS firm_b_id \gset

SELECT set_config('taxos_test.user_a', :'user_a', true);
SELECT set_config('taxos_test.user_b', :'user_b', true);
SELECT set_config('taxos_test.firm_a_id', :'firm_a_id', true);
SELECT set_config('taxos_test.firm_b_id', :'firm_b_id', true);

-- Creating each firm must provision exactly one active owner membership.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM taxos_prototype.firm_memberships
    WHERE firm_id = current_setting('taxos_test.firm_a_id')::uuid
      AND user_id = current_setting('taxos_test.user_a')::uuid
      AND role = 'owner' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Firm A creator was not provisioned as active owner';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM taxos_prototype.firm_memberships
    WHERE firm_id = current_setting('taxos_test.firm_b_id')::uuid
      AND user_id = current_setting('taxos_test.user_b')::uuid
      AND role = 'owner' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Firm B creator was not provisioned as active owner';
  END IF;
END;
$$;

INSERT INTO taxos_prototype.firm_memberships (firm_id, user_id, role, status)
VALUES (current_setting('taxos_test.firm_b_id')::uuid, current_setting('taxos_test.user_a')::uuid, 'accountant', 'suspended');

INSERT INTO taxos_prototype.clients (firm_id, client_type, display_name)
VALUES
  (current_setting('taxos_test.firm_a_id')::uuid, 'company', 'Firm A Client')
RETURNING id AS client_a_id \gset

INSERT INTO taxos_prototype.clients (firm_id, client_type, display_name, created_by)
VALUES (current_setting('taxos_test.firm_b_id')::uuid, 'company', 'Firm B Client', current_setting('taxos_test.user_b')::uuid)
RETURNING id AS client_b_id \gset

SELECT set_config('taxos_test.client_a_id', :'client_a_id', true);
SELECT set_config('taxos_test.client_b_id', :'client_b_id', true);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'user_a', true);
SELECT set_config(
  'request.jwt.claims',
  json_build_object('sub', :'user_a')::text,
  true
);

-- Active member sees their own firm's client.
DO $$
DECLARE
  visible_count integer;
BEGIN
  SELECT count(*) INTO visible_count
  FROM taxos_prototype.clients
  WHERE firm_id = current_setting('taxos_test.firm_a_id')::uuid;
  IF visible_count <> 1 THEN
    RAISE EXCEPTION 'Expected one Firm A client, got %', visible_count;
  END IF;
END;
$$;

-- Membership in Firm A must not expose Firm B, where this user is suspended.
DO $$
DECLARE
  visible_count integer;
BEGIN
  SELECT count(*) INTO visible_count
  FROM taxos_prototype.clients
  WHERE firm_id = current_setting('taxos_test.firm_b_id')::uuid;
  IF visible_count <> 0 THEN
    RAISE EXCEPTION 'Cross-firm isolation failed; Firm B rows visible: %', visible_count;
  END IF;
END;
$$;

-- A cross-firm insert must be rejected by RLS.
DO $$
BEGIN
  BEGIN
    INSERT INTO taxos_prototype.clients (firm_id, client_type, display_name)
    VALUES (current_setting('taxos_test.firm_b_id')::uuid, 'company', 'Unauthorized client');
    RAISE EXCEPTION 'RLS allowed a cross-firm client insert';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;

-- A valid child insert succeeds for the caller's own client.
INSERT INTO taxos_prototype.client_identifiers (
  firm_id, client_id, identifier_type, identifier_value, normalized_value
)
VALUES (
  current_setting('taxos_test.firm_a_id')::uuid, current_setting('taxos_test.client_a_id')::uuid,
  'tax_registration', '123456789', '123456789'
);

-- RLS alone would allow the caller to write within Firm A; the composite FK
-- must still reject a Firm B client ID paired with Firm A's tenant key.
DO $$
BEGIN
  BEGIN
    INSERT INTO taxos_prototype.client_identifiers (
      firm_id, client_id, identifier_type, identifier_value, normalized_value
    )
    VALUES (
      current_setting('taxos_test.firm_a_id')::uuid, current_setting('taxos_test.client_b_id')::uuid,
      'tax_registration', '987654321', '987654321'
    );
    RAISE EXCEPTION 'Composite tenant foreign key allowed a cross-firm parent';
  EXCEPTION
    WHEN foreign_key_violation THEN NULL;
  END;
END;
$$;

-- The authenticated application role must not have direct membership-write grants.
DO $$
BEGIN
  IF has_table_privilege(current_user, 'taxos_prototype.firm_memberships', 'INSERT')
     OR has_table_privilege(current_user, 'taxos_prototype.firm_memberships', 'UPDATE')
     OR has_table_privilege(current_user, 'taxos_prototype.firm_memberships', 'DELETE') THEN
    RAISE EXCEPTION 'Authenticated role has unsafe direct membership write privileges';
  END IF;
END;
$$;

RESET ROLE;
ROLLBACK;

\echo 'TaxOS prototype RLS checks completed successfully; fixture transaction rolled back.'
