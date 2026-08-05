-- Migration: 20260717100100_shared_functions
-- Description: Shared trigger functions and tenant helper for RLS
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- down:
--   DROP FUNCTION IF EXISTS public.update_updated_at() CASCADE;

-- ---------------------------------------------------------------------------
-- Auto-update updated_at on row modification
-- Decision: Central trigger function avoids duplicating logic across 15+ tables.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
