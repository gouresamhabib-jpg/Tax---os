-- Seed: Reference data for TaxOS Sprint 1
-- Description: Expense and document categories (global lookup tables)
-- Run via: supabase db seed (configured in supabase/config.toml)
-- Note: Does NOT seed accountants/clients — those require auth.users entries.

-- ---------------------------------------------------------------------------
-- expense_categories
-- ---------------------------------------------------------------------------
INSERT INTO public.expense_categories (name, slug, icon, is_deductible, sort_order) VALUES
  ('Office Supplies',     'office_supplies',     'briefcase',  true,  1),
  ('Travel',              'travel',              'plane',      true,  2),
  ('Meals & Entertainment','meals',              'utensils',   true,  3),
  ('Utilities',           'utilities',           'zap',        true,  4),
  ('Insurance',           'insurance',           'shield',     true,  5),
  ('Professional Services','professional_services','users',   true,  6),
  ('Marketing',           'marketing',           'megaphone',  true,  7),
  ('Equipment',           'equipment',           'monitor',    true,  8),
  ('Rent',                'rent',                'home',       true,  9),
  ('Software & Subscriptions', 'software',       'cloud',      true,  10),
  ('Other',               'other',               'folder',     false, 99)
ON CONFLICT (slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- document_categories
-- ---------------------------------------------------------------------------
INSERT INTO public.document_categories (name, slug, sort_order) VALUES
  ('W-2',           'w2',            1),
  ('1099',          '1099',          2),
  ('Receipt',       'receipt',       3),
  ('Invoice',       'invoice',       4),
  ('Prior Return',  'prior_return',  5),
  ('Bank Statement','bank_statement',6),
  ('ID Verification','id_verification',7),
  ('Other',         'other',         99)
ON CONFLICT (slug) DO NOTHING;
