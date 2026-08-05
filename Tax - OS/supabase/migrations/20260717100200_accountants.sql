-- Migration: 20260717100200_accountants
-- Description: Tenant root table — one row per accountant (Sprint 1: solo practitioner)
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- down:
--   DROP TRIGGER IF EXISTS accountants_updated_at ON public.accountants;
--   DROP TABLE IF EXISTS public.accountants CASCADE;
--   DROP FUNCTION IF EXISTS public.current_accountant_id() CASCADE;

-- ---------------------------------------------------------------------------
-- accountants — MULTI-TENANT ROOT
-- Decision: Each accountant is an isolated tenant. All business data carries
-- accountant_id. Sprint 1 models solo practitioners (1 auth user = 1 tenant).
-- Future: firm_members table will allow multiple staff under one accountant row.
-- ---------------------------------------------------------------------------
CREATE TABLE public.accountants (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
  firm_name       text NOT NULL,
  full_name       text NOT NULL,
  email           text NOT NULL,
  phone           text,
  license_type    public.license_type NOT NULL DEFAULT 'other',
  license_number  text,
  license_state   char(2),
  address         jsonb,
  avatar_url      text,
  status          public.accountant_status NOT NULL DEFAULT 'pending_verification',
  onboarding_completed boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT accountants_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT accountants_license_state_format CHECK (
    license_state IS NULL OR license_state ~ '^[A-Z]{2}$'
  )
);

CREATE INDEX idx_accountants_user_id ON public.accountants (user_id);
CREATE INDEX idx_accountants_status ON public.accountants (status) WHERE status = 'active';

CREATE TRIGGER accountants_updated_at
  BEFORE UPDATE ON public.accountants
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

COMMENT ON TABLE public.accountants IS
  'Tenant root. Each accountant sees only rows where accountant_id matches their id.';

-- Tenant helper (depends on accountants table)
CREATE OR REPLACE FUNCTION public.current_accountant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT a.id
  FROM public.accountants a
  WHERE a.user_id = auth.uid()
  LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- RLS: accountants
-- Decision: Accountants can read/update only their own tenant row.
-- INSERT handled by handle_new_user trigger (SECURITY DEFINER), not direct client insert.
-- ---------------------------------------------------------------------------
ALTER TABLE public.accountants ENABLE ROW LEVEL SECURITY;

CREATE POLICY accountants_select_own ON public.accountants
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY accountants_update_own ON public.accountants
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
