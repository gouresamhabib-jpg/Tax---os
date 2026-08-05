-- Migration: 20260717101000_triggers_and_auth
-- Description: Auth signup handler, return total recalculation, subscription limits RPC
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- down:
--   DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
--   DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
--   DROP FUNCTION IF EXISTS public.calculate_return_totals() CASCADE;
--   DROP FUNCTION IF EXISTS public.check_subscription_limit(text, int) CASCADE;

-- ---------------------------------------------------------------------------
-- handle_new_user — auto-provision tenant on signup
-- Decision: SECURITY DEFINER trigger creates accountant row + free subscription atomically.
-- Runs in auth schema context; bypasses RLS safely for provisioning only.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_full_name text;
  v_firm_name text;
BEGIN
  v_full_name := coalesce(
    NEW.raw_user_meta_data ->> 'full_name',
    split_part(NEW.email, '@', 1)
  );
  v_firm_name := coalesce(
    NEW.raw_user_meta_data ->> 'firm_name',
    v_full_name || ' Tax Practice'
  );

  INSERT INTO public.accountants (user_id, firm_name, full_name, email, status)
  VALUES (NEW.id, v_firm_name, v_full_name, NEW.email, 'pending_verification');

  INSERT INTO public.subscriptions (accountant_id, plan_id, status)
  SELECT id, 'free', 'active'
  FROM public.accountants
  WHERE user_id = NEW.id;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ---------------------------------------------------------------------------
-- calculate_return_totals — keep return header in sync with line items
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_return_totals()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_return_id uuid;
  v_total_income numeric(12,2);
  v_total_deductions numeric(12,2);
  v_total_credits numeric(12,2);
BEGIN
  v_return_id := coalesce(NEW.tax_return_id, OLD.tax_return_id);

  SELECT coalesce(sum(gross_amount), 0) INTO v_total_income
  FROM public.income_entries WHERE tax_return_id = v_return_id;

  SELECT coalesce(sum(amount), 0) INTO v_total_deductions
  FROM public.deduction_entries WHERE tax_return_id = v_return_id;

  SELECT coalesce(sum(amount), 0) INTO v_total_credits
  FROM public.credit_entries WHERE tax_return_id = v_return_id;

  UPDATE public.tax_returns
  SET
    total_income = v_total_income,
    total_deductions = v_total_deductions,
    total_credits = v_total_credits,
    updated_at = now()
  WHERE id = v_return_id;

  RETURN coalesce(NEW, OLD);
END;
$$;

CREATE TRIGGER income_entries_recalc_totals
  AFTER INSERT OR UPDATE OR DELETE ON public.income_entries
  FOR EACH ROW EXECUTE FUNCTION public.calculate_return_totals();

CREATE TRIGGER deduction_entries_recalc_totals
  AFTER INSERT OR UPDATE OR DELETE ON public.deduction_entries
  FOR EACH ROW EXECUTE FUNCTION public.calculate_return_totals();

CREATE TRIGGER credit_entries_recalc_totals
  AFTER INSERT OR UPDATE OR DELETE ON public.credit_entries
  FOR EACH ROW EXECUTE FUNCTION public.calculate_return_totals();

-- ---------------------------------------------------------------------------
-- check_subscription_limit — server-side plan enforcement RPC
-- Decision: Called from Edge Functions before expensive operations.
-- Returns true if under limit, false if exceeded.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_subscription_limit(
  p_feature text,
  p_current_count int DEFAULT 0
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plan public.subscription_plan;
  v_limit int;
BEGIN
  SELECT s.plan_id INTO v_plan
  FROM public.subscriptions s
  WHERE s.accountant_id = public.current_accountant_id();

  IF v_plan IS NULL THEN
    RETURN false;
  END IF;

  v_limit := CASE
    WHEN p_feature = 'clients' THEN
      CASE v_plan WHEN 'free' THEN 5 WHEN 'pro' THEN 100 WHEN 'premium' THEN 999999 END
    WHEN p_feature = 'documents_mb' THEN
      CASE v_plan WHEN 'free' THEN 100 WHEN 'pro' THEN 5120 WHEN 'premium' THEN 25600 END
    WHEN p_feature = 'returns_per_year' THEN
      CASE v_plan WHEN 'free' THEN 10 WHEN 'pro' THEN 200 WHEN 'premium' THEN 999999 END
    ELSE 999999
  END;

  RETURN p_current_count < v_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_subscription_limit(text, int) TO authenticated;
