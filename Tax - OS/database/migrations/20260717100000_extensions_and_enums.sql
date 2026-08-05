-- Migration: 20260717100000_extensions_and_enums
-- Description: PostgreSQL extensions and domain enums for TaxOS Sprint 1
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- down:
--   DROP TYPE IF EXISTS public.notification_type CASCADE;
--   DROP TYPE IF EXISTS public.subscription_status CASCADE;
--   DROP TYPE IF EXISTS public.subscription_plan CASCADE;
--   DROP TYPE IF EXISTS public.invoice_status CASCADE;
--   DROP TYPE IF EXISTS public.credit_type CASCADE;
--   DROP TYPE IF EXISTS public.deduction_type CASCADE;
--   DROP TYPE IF EXISTS public.income_type CASCADE;
--   DROP TYPE IF EXISTS public.tax_return_status CASCADE;
--   DROP TYPE IF EXISTS public.filing_status CASCADE;
--   DROP TYPE IF EXISTS public.client_type CASCADE;
--   DROP TYPE IF EXISTS public.accountant_status CASCADE;
--   DROP TYPE IF EXISTS public.license_type CASCADE;
--   DROP EXTENSION IF EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
-- pgcrypto: gen_random_uuid() for UUID primary keys (Supabase includes this by default)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
-- Decision: Use PostgreSQL ENUM types instead of plain text for domain values.
-- Benefits: storage efficiency, invalid-value rejection at DB layer, self-documenting schema.
-- Trade-off: adding values requires ALTER TYPE ... ADD VALUE migration (acceptable for tax domain).

CREATE TYPE public.license_type AS ENUM (
  'cpa',
  'ea',
  'attorney',
  'other'
);

CREATE TYPE public.accountant_status AS ENUM (
  'active',
  'suspended',
  'pending_verification'
);

CREATE TYPE public.client_type AS ENUM (
  'individual',
  'sole_proprietorship',
  'llc',
  'partnership',
  's_corp',
  'c_corp'
);

CREATE TYPE public.filing_status AS ENUM (
  'single',
  'mfj',
  'mfs',
  'hoh',
  'qw'
);

CREATE TYPE public.tax_return_status AS ENUM (
  'draft',
  'ready',
  'submitted',
  'accepted',
  'rejected',
  'amended'
);

CREATE TYPE public.income_type AS ENUM (
  'w2',
  '1099_nec',
  '1099_int',
  '1099_div',
  '1099_b',
  '1099_r',
  'schedule_c',
  'rental',
  'capital_gains',
  'other'
);

CREATE TYPE public.deduction_type AS ENUM (
  'standard',
  'itemized',
  'student_loan',
  'hsa',
  'ira',
  'charitable',
  'mortgage_interest',
  'medical',
  'state_local_tax',
  'business_expense',
  'other'
);

CREATE TYPE public.credit_type AS ENUM (
  'child_tax_credit',
  'earned_income_credit',
  'education_credit',
  'child_dependent_care',
  'retirement_savings',
  'energy_efficiency',
  'other'
);

CREATE TYPE public.invoice_status AS ENUM (
  'draft',
  'sent',
  'paid',
  'overdue',
  'cancelled'
);

CREATE TYPE public.subscription_plan AS ENUM (
  'free',
  'pro',
  'premium'
);

CREATE TYPE public.subscription_status AS ENUM (
  'active',
  'cancelled',
  'past_due',
  'trialing'
);

CREATE TYPE public.notification_type AS ENUM (
  'deadline',
  'payment',
  'system',
  'filing_update',
  'client_activity'
);
