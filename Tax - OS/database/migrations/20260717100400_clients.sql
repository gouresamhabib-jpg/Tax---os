-- Migration: 20260717100400_clients
-- Description: Taxpayer clients managed by an accountant (tenant-scoped)
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- down:
--   DROP TRIGGER IF EXISTS clients_tenant_check ON public.clients;
--   DROP TRIGGER IF EXISTS clients_updated_at ON public.clients;
--   DROP TABLE IF EXISTS public.clients CASCADE;
--   DROP FUNCTION IF EXISTS public.enforce_client_tenant_match() CASCADE;

-- ---------------------------------------------------------------------------
-- clients
-- Decision: "Client" = taxpayer record owned by an accountant, NOT a login account.
-- Optional portal_user_id reserved for future client self-service portal (v2+).
-- SSN is never stored in plain text — only ssn_last4 for display + external vault ref.
-- ---------------------------------------------------------------------------
CREATE TABLE public.clients (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  accountant_id   uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_type     public.client_type NOT NULL DEFAULT 'individual',
  first_name      text NOT NULL,
  last_name       text NOT NULL,
  display_name    text GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
  email           text,
  phone           text,
  address         jsonb,
  ssn_last4       char(4),
  ssn_vault_ref   text,
  date_of_birth   date,
  ein             text,
  notes           text,
  portal_user_id  uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  deleted_at      timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT clients_ssn_last4_format CHECK (
    ssn_last4 IS NULL OR ssn_last4 ~ '^\d{4}$'
  ),
  CONSTRAINT clients_email_format CHECK (
    email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  )
);

-- Partial unique: no duplicate active emails per accountant
CREATE UNIQUE INDEX idx_clients_accountant_email_active
  ON public.clients (accountant_id, lower(email))
  WHERE deleted_at IS NULL AND email IS NOT NULL;

CREATE INDEX idx_clients_accountant_id ON public.clients (accountant_id);
CREATE INDEX idx_clients_accountant_active ON public.clients (accountant_id)
  WHERE deleted_at IS NULL;
CREATE INDEX idx_clients_display_name ON public.clients (accountant_id, last_name, first_name);

CREATE TRIGGER clients_updated_at
  BEFORE UPDATE ON public.clients
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ---------------------------------------------------------------------------
-- Tenant consistency trigger
-- Decision: Prevents inserting child rows with a client_id from another tenant.
-- Defense-in-depth beyond RLS — blocks malicious INSERT even if policy misconfigured.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_client_tenant_match()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_client_accountant_id uuid;
BEGIN
  IF NEW.client_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT c.accountant_id INTO v_client_accountant_id
  FROM public.clients c
  WHERE c.id = NEW.client_id;

  IF v_client_accountant_id IS NULL THEN
    RAISE EXCEPTION 'client_id % does not exist', NEW.client_id;
  END IF;

  IF NEW.accountant_id IS DISTINCT FROM v_client_accountant_id THEN
    RAISE EXCEPTION 'client_id % does not belong to accountant_id %', NEW.client_id, NEW.accountant_id;
  END IF;

  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS: clients
-- ---------------------------------------------------------------------------
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

CREATE POLICY clients_select_own ON public.clients
  FOR SELECT TO authenticated
  USING (accountant_id = public.current_accountant_id());

CREATE POLICY clients_insert_own ON public.clients
  FOR INSERT TO authenticated
  WITH CHECK (accountant_id = public.current_accountant_id());

CREATE POLICY clients_update_own ON public.clients
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());

CREATE POLICY clients_delete_own ON public.clients
  FOR DELETE TO authenticated
  USING (accountant_id = public.current_accountant_id());
