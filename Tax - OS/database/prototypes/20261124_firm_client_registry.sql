-- TaxOS local prototype ONLY — not a Supabase migration.
-- Target: disposable local Supabase/PostgreSQL instance.
-- This creates an isolated schema and does not modify public.* or existing legacy tables.
--
-- Required Supabase roles/schemas: auth.users, auth.uid(), authenticated, anon.
-- Run as a database owner (normally postgres) on a disposable local instance.

CREATE SCHEMA IF NOT EXISTS taxos_prototype;

-- ---------------------------------------------------------------------------
-- Tenant membership helpers
-- SECURITY DEFINER functions are owned by the schema/database owner.
-- The caller identity always comes from auth.uid(), never a client parameter.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION taxos_prototype.is_active_firm_member(p_firm_id uuid)
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
      AND membership.user_id = auth.uid()
      AND membership.status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION taxos_prototype.has_firm_role(
  p_firm_id uuid,
  p_allowed_roles text[]
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
      AND membership.user_id = auth.uid()
      AND membership.status = 'active'
      AND membership.role = ANY (p_allowed_roles)
  );
$$;

CREATE OR REPLACE FUNCTION taxos_prototype.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Firm and membership
-- ---------------------------------------------------------------------------

CREATE TABLE taxos_prototype.firms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(btrim(name)) > 0),
  legal_name text,
  country_code char(2) NOT NULL DEFAULT 'EG',
  default_currency char(3) NOT NULL DEFAULT 'EGP',
  timezone text NOT NULL DEFAULT 'Africa/Cairo',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'suspended', 'closed')),
  created_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE taxos_prototype.firm_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL REFERENCES taxos_prototype.firms(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  role text NOT NULL CHECK (
    role IN ('owner', 'admin', 'manager', 'accountant', 'reviewer', 'staff', 'read_only')
  ),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('invited', 'active', 'suspended', 'revoked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT firm_memberships_firm_user_unique UNIQUE (firm_id, user_id),
  CONSTRAINT firm_memberships_firm_id_id_unique UNIQUE (firm_id, id)
);

CREATE INDEX firm_memberships_user_status_idx
  ON taxos_prototype.firm_memberships (user_id, status, firm_id);

-- Firm creation and initial owner membership happen atomically.
CREATE OR REPLACE FUNCTION taxos_prototype.add_initial_firm_owner()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, taxos_prototype, auth
AS $$
BEGIN
  INSERT INTO taxos_prototype.firm_memberships (firm_id, user_id, role, status)
  VALUES (NEW.id, NEW.created_by, 'owner', 'active');
  RETURN NEW;
END;
$$;

CREATE TRIGGER firms_add_initial_owner
AFTER INSERT ON taxos_prototype.firms
FOR EACH ROW EXECUTE FUNCTION taxos_prototype.add_initial_firm_owner();

CREATE TRIGGER firms_updated_at
BEFORE UPDATE ON taxos_prototype.firms
FOR EACH ROW EXECUTE FUNCTION taxos_prototype.set_updated_at();

CREATE TRIGGER memberships_updated_at
BEFORE UPDATE ON taxos_prototype.firm_memberships
FOR EACH ROW EXECUTE FUNCTION taxos_prototype.set_updated_at();

-- ---------------------------------------------------------------------------
-- Client master and typed related records
-- ---------------------------------------------------------------------------

CREATE TABLE taxos_prototype.clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL REFERENCES taxos_prototype.firms(id) ON DELETE RESTRICT,
  client_type text NOT NULL CHECK (client_type IN ('company', 'individual')),
  display_name text NOT NULL CHECK (length(btrim(display_name)) > 0),
  legal_name text,
  email text,
  phone text,
  address jsonb NOT NULL DEFAULT '{}'::jsonb,
  notes text,
  archived_at timestamptz,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT clients_firm_id_id_unique UNIQUE (firm_id, id),
  CONSTRAINT clients_email_format CHECK (
    email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
  )
);

CREATE INDEX clients_firm_active_name_idx
  ON taxos_prototype.clients (firm_id, lower(display_name))
  WHERE archived_at IS NULL;

CREATE INDEX clients_firm_created_idx
  ON taxos_prototype.clients (firm_id, created_at DESC);

CREATE TABLE taxos_prototype.client_identifiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  client_id uuid NOT NULL,
  identifier_type text NOT NULL CHECK (
    identifier_type IN ('tax_registration', 'vat_registration', 'commercial_registration', 'other')
  ),
  identifier_value text NOT NULL CHECK (length(btrim(identifier_value)) > 0),
  normalized_value text NOT NULL CHECK (length(btrim(normalized_value)) > 0),
  label text,
  verified_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT client_identifiers_client_fk
    FOREIGN KEY (firm_id, client_id)
    REFERENCES taxos_prototype.clients (firm_id, id)
    ON DELETE CASCADE,
  CONSTRAINT client_identifiers_firm_id_id_unique UNIQUE (firm_id, id)
);

CREATE UNIQUE INDEX client_identifiers_unique_active_idx
  ON taxos_prototype.client_identifiers (firm_id, identifier_type, normalized_value)
  WHERE archived_at IS NULL;

CREATE INDEX client_identifiers_client_idx
  ON taxos_prototype.client_identifiers (firm_id, client_id);

CREATE TABLE taxos_prototype.client_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  client_id uuid NOT NULL,
  full_name text NOT NULL CHECK (length(btrim(full_name)) > 0),
  job_title text,
  email text,
  phone text,
  is_primary boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT client_contacts_client_fk
    FOREIGN KEY (firm_id, client_id)
    REFERENCES taxos_prototype.clients (firm_id, id)
    ON DELETE CASCADE,
  CONSTRAINT client_contacts_firm_id_id_unique UNIQUE (firm_id, id)
);

CREATE UNIQUE INDEX client_contacts_one_primary_idx
  ON taxos_prototype.client_contacts (firm_id, client_id)
  WHERE is_primary;

CREATE INDEX client_contacts_client_idx
  ON taxos_prototype.client_contacts (firm_id, client_id);

CREATE TABLE taxos_prototype.client_branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  client_id uuid NOT NULL,
  branch_name text NOT NULL CHECK (length(btrim(branch_name)) > 0),
  branch_code text,
  address jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_head_office boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT client_branches_client_fk
    FOREIGN KEY (firm_id, client_id)
    REFERENCES taxos_prototype.clients (firm_id, id)
    ON DELETE CASCADE,
  CONSTRAINT client_branches_firm_id_id_unique UNIQUE (firm_id, id)
);

CREATE UNIQUE INDEX client_branches_one_head_office_idx
  ON taxos_prototype.client_branches (firm_id, client_id)
  WHERE is_head_office;

CREATE INDEX client_branches_client_idx
  ON taxos_prototype.client_branches (firm_id, client_id);

CREATE TRIGGER clients_updated_at
BEFORE UPDATE ON taxos_prototype.clients
FOR EACH ROW EXECUTE FUNCTION taxos_prototype.set_updated_at();

CREATE TRIGGER contacts_updated_at
BEFORE UPDATE ON taxos_prototype.client_contacts
FOR EACH ROW EXECUTE FUNCTION taxos_prototype.set_updated_at();

CREATE TRIGGER branches_updated_at
BEFORE UPDATE ON taxos_prototype.client_branches
FOR EACH ROW EXECUTE FUNCTION taxos_prototype.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

ALTER TABLE taxos_prototype.firms ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxos_prototype.firm_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxos_prototype.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxos_prototype.client_identifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxos_prototype.client_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxos_prototype.client_branches ENABLE ROW LEVEL SECURITY;

CREATE POLICY firms_select_member ON taxos_prototype.firms
FOR SELECT TO authenticated
USING (taxos_prototype.is_active_firm_member(id));

CREATE POLICY firms_insert_creator ON taxos_prototype.firms
FOR INSERT TO authenticated
WITH CHECK (created_by = auth.uid());

CREATE POLICY firms_update_admin ON taxos_prototype.firms
FOR UPDATE TO authenticated
USING (taxos_prototype.has_firm_role(id, ARRAY['owner', 'admin']))
WITH CHECK (taxos_prototype.has_firm_role(id, ARRAY['owner', 'admin']));

CREATE POLICY memberships_select_member ON taxos_prototype.firm_memberships
FOR SELECT TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

-- No direct INSERT/UPDATE/DELETE policy for memberships. Provisioning and
-- membership lifecycle must use narrowly scoped, audited server-side functions.

CREATE POLICY clients_select_member ON taxos_prototype.clients
FOR SELECT TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY clients_insert_member ON taxos_prototype.clients
FOR INSERT TO authenticated
WITH CHECK (
  taxos_prototype.is_active_firm_member(firm_id)
  AND created_by = auth.uid()
);

CREATE POLICY clients_update_member ON taxos_prototype.clients
FOR UPDATE TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id))
WITH CHECK (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY identifiers_select_member ON taxos_prototype.client_identifiers
FOR SELECT TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY identifiers_insert_member ON taxos_prototype.client_identifiers
FOR INSERT TO authenticated
WITH CHECK (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY identifiers_update_member ON taxos_prototype.client_identifiers
FOR UPDATE TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id))
WITH CHECK (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY identifiers_delete_member ON taxos_prototype.client_identifiers
FOR DELETE TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY contacts_select_member ON taxos_prototype.client_contacts
FOR SELECT TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY contacts_insert_member ON taxos_prototype.client_contacts
FOR INSERT TO authenticated
WITH CHECK (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY contacts_update_member ON taxos_prototype.client_contacts
FOR UPDATE TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id))
WITH CHECK (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY contacts_delete_member ON taxos_prototype.client_contacts
FOR DELETE TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY branches_select_member ON taxos_prototype.client_branches
FOR SELECT TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY branches_insert_member ON taxos_prototype.client_branches
FOR INSERT TO authenticated
WITH CHECK (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY branches_update_member ON taxos_prototype.client_branches
FOR UPDATE TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id))
WITH CHECK (taxos_prototype.is_active_firm_member(firm_id));

CREATE POLICY branches_delete_member ON taxos_prototype.client_branches
FOR DELETE TO authenticated
USING (taxos_prototype.is_active_firm_member(firm_id));

-- Grants for the authenticated application role. Membership writes remain revoked.
GRANT USAGE ON SCHEMA taxos_prototype TO authenticated;
GRANT SELECT, INSERT ON taxos_prototype.firms TO authenticated;
REVOKE UPDATE ON taxos_prototype.firms FROM authenticated;
GRANT UPDATE (name, legal_name, default_currency, timezone)
  ON taxos_prototype.firms TO authenticated;
GRANT SELECT ON taxos_prototype.firm_memberships TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON taxos_prototype.firm_memberships FROM authenticated;
GRANT SELECT, INSERT ON taxos_prototype.clients TO authenticated;
REVOKE UPDATE ON taxos_prototype.clients FROM authenticated;
GRANT UPDATE (client_type, display_name, legal_name, email, phone, address, notes, archived_at)
  ON taxos_prototype.clients TO authenticated;
GRANT SELECT, INSERT, DELETE ON taxos_prototype.client_identifiers TO authenticated;
GRANT UPDATE (identifier_type, identifier_value, normalized_value, label, verified_at, archived_at)
  ON taxos_prototype.client_identifiers TO authenticated;
GRANT SELECT, INSERT, DELETE ON taxos_prototype.client_contacts TO authenticated;
GRANT UPDATE (full_name, job_title, email, phone, is_primary, notes)
  ON taxos_prototype.client_contacts TO authenticated;
GRANT SELECT, INSERT, DELETE ON taxos_prototype.client_branches TO authenticated;
GRANT UPDATE (branch_name, branch_code, address, is_head_office)
  ON taxos_prototype.client_branches TO authenticated;

REVOKE ALL ON FUNCTION taxos_prototype.is_active_firm_member(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION taxos_prototype.has_firm_role(uuid, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION taxos_prototype.is_active_firm_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION taxos_prototype.has_firm_role(uuid, text[]) TO authenticated;

COMMENT ON SCHEMA taxos_prototype IS
  'Isolated TaxOS firm/client tenancy prototype. Not production schema.';
COMMENT ON TABLE taxos_prototype.client_identifiers IS
  'Tenant-protected typed business/tax identifiers. Do not include national ID in this initial prototype.';
