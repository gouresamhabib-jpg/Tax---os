-- Migration: 20260717100300_reference_tables
-- Description: Global reference/lookup tables (not tenant-scoped)
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- down:
--   DROP TABLE IF EXISTS public.document_categories CASCADE;
--   DROP TABLE IF EXISTS public.expense_categories CASCADE;

-- ---------------------------------------------------------------------------
-- expense_categories
-- Decision: Shared across all tenants — IRS-aligned categories are identical for everyone.
-- Writes restricted to service_role; accountants only SELECT.
-- ---------------------------------------------------------------------------
CREATE TABLE public.expense_categories (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  slug          text NOT NULL,
  icon          text,
  is_deductible boolean NOT NULL DEFAULT true,
  sort_order    int NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT expense_categories_name_unique UNIQUE (name),
  CONSTRAINT expense_categories_slug_unique UNIQUE (slug),
  CONSTRAINT expense_categories_slug_format CHECK (slug ~ '^[a-z0-9_]+$')
);

CREATE INDEX idx_expense_categories_sort ON public.expense_categories (sort_order);

-- ---------------------------------------------------------------------------
-- document_categories
-- ---------------------------------------------------------------------------
CREATE TABLE public.document_categories (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL,
  slug       text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT document_categories_name_unique UNIQUE (name),
  CONSTRAINT document_categories_slug_unique UNIQUE (slug),
  CONSTRAINT document_categories_slug_format CHECK (slug ~ '^[a-z0-9_]+$')
);

CREATE INDEX idx_document_categories_sort ON public.document_categories (sort_order);

-- ---------------------------------------------------------------------------
-- RLS: reference tables — read-only for authenticated users
-- ---------------------------------------------------------------------------
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY expense_categories_select ON public.expense_categories
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY document_categories_select ON public.document_categories
  FOR SELECT TO authenticated
  USING (true);
