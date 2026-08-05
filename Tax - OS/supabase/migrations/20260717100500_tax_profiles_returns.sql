-- Migration: 20260717100500_tax_profiles_returns
-- Description: Tax profiles and tax return headers (tenant + client scoped)
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- down:
--   DROP TRIGGER IF EXISTS tax_returns_tenant_check ON public.tax_returns;
--   DROP TRIGGER IF EXISTS tax_profiles_tenant_check ON public.tax_profiles;
--   DROP TABLE IF EXISTS public.tax_returns CASCADE;
--   DROP TABLE IF EXISTS public.tax_profiles CASCADE;

-- ---------------------------------------------------------------------------
-- tax_profiles — per client, per tax year configuration
-- Decision: Separated from clients because a client may have profiles across years.
-- income_types uses text[] (not enum[]) for flexibility when adding new income sources.
-- ---------------------------------------------------------------------------
CREATE TABLE public.tax_profiles (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  accountant_id         uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_id             uuid NOT NULL REFERENCES public.clients (id) ON DELETE CASCADE,
  tax_year              int NOT NULL,
  filing_status         public.filing_status NOT NULL,
  income_types          text[] NOT NULL DEFAULT '{}',
  dependents            jsonb NOT NULL DEFAULT '[]',
  state_of_residence    char(2),
  onboarding_completed  boolean NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT tax_profiles_tax_year_range CHECK (tax_year BETWEEN 2000 AND 2100),
  CONSTRAINT tax_profiles_state_format CHECK (
    state_of_residence IS NULL OR state_of_residence ~ '^[A-Z]{2}$'
  )
);

CREATE UNIQUE INDEX idx_tax_profiles_client_year
  ON public.tax_profiles (client_id, tax_year);

CREATE INDEX idx_tax_profiles_accountant ON public.tax_profiles (accountant_id);
CREATE INDEX idx_tax_profiles_accountant_year ON public.tax_profiles (accountant_id, tax_year);

CREATE TRIGGER tax_profiles_updated_at
  BEFORE UPDATE ON public.tax_profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER tax_profiles_tenant_check
  BEFORE INSERT OR UPDATE ON public.tax_profiles
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_tenant_match();

-- ---------------------------------------------------------------------------
-- tax_returns — 1040 return header with computed totals
-- Decision: Denormalized totals updated by calculate_return_totals() trigger.
-- Partial unique index prevents duplicate active returns per client/year.
-- ---------------------------------------------------------------------------
CREATE TABLE public.tax_returns (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  accountant_id          uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_id              uuid NOT NULL REFERENCES public.clients (id) ON DELETE CASCADE,
  tax_year               int NOT NULL,
  status                 public.tax_return_status NOT NULL DEFAULT 'draft',
  filing_status          public.filing_status NOT NULL,
  personal_info          jsonb NOT NULL DEFAULT '{}',
  total_income           numeric(12,2) NOT NULL DEFAULT 0,
  total_deductions       numeric(12,2) NOT NULL DEFAULT 0,
  total_credits          numeric(12,2) NOT NULL DEFAULT 0,
  total_tax              numeric(12,2) NOT NULL DEFAULT 0,
  refund_amount          numeric(12,2) NOT NULL DEFAULT 0,
  completion_percentage  int NOT NULL DEFAULT 0,
  submitted_at           timestamptz,
  pdf_url                text,
  deleted_at             timestamptz,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT tax_returns_tax_year_range CHECK (tax_year BETWEEN 2000 AND 2100),
  CONSTRAINT tax_returns_completion_range CHECK (completion_percentage BETWEEN 0 AND 100),
  CONSTRAINT tax_returns_totals_non_negative CHECK (
    total_income >= 0 AND total_deductions >= 0 AND total_credits >= 0 AND total_tax >= 0
  )
);

CREATE UNIQUE INDEX idx_tax_returns_client_year_active
  ON public.tax_returns (client_id, tax_year)
  WHERE deleted_at IS NULL AND status <> 'amended';

CREATE INDEX idx_tax_returns_accountant ON public.tax_returns (accountant_id);
CREATE INDEX idx_tax_returns_accountant_year ON public.tax_returns (accountant_id, tax_year);
CREATE INDEX idx_tax_returns_accountant_status ON public.tax_returns (accountant_id, status)
  WHERE deleted_at IS NULL;

CREATE TRIGGER tax_returns_updated_at
  BEFORE UPDATE ON public.tax_returns
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER tax_returns_tenant_check
  BEFORE INSERT OR UPDATE ON public.tax_returns
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_tenant_match();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.tax_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tax_returns ENABLE ROW LEVEL SECURITY;

CREATE POLICY tax_profiles_select_own ON public.tax_profiles
  FOR SELECT TO authenticated
  USING (accountant_id = public.current_accountant_id());

CREATE POLICY tax_profiles_insert_own ON public.tax_profiles
  FOR INSERT TO authenticated
  WITH CHECK (accountant_id = public.current_accountant_id());

CREATE POLICY tax_profiles_update_own ON public.tax_profiles
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());

CREATE POLICY tax_profiles_delete_own ON public.tax_profiles
  FOR DELETE TO authenticated
  USING (accountant_id = public.current_accountant_id());

CREATE POLICY tax_returns_select_own ON public.tax_returns
  FOR SELECT TO authenticated
  USING (accountant_id = public.current_accountant_id());

CREATE POLICY tax_returns_insert_own ON public.tax_returns
  FOR INSERT TO authenticated
  WITH CHECK (accountant_id = public.current_accountant_id());

CREATE POLICY tax_returns_update_own ON public.tax_returns
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());

CREATE POLICY tax_returns_delete_own ON public.tax_returns
  FOR DELETE TO authenticated
  USING (accountant_id = public.current_accountant_id());
