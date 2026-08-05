-- Seed: Development demo data (LOCAL ONLY — do not run in production)
-- Description: Sample accountants and clients for local testing
-- Prerequisites: Create auth users first via Supabase Auth, then update UUIDs below.
--
-- Usage:
--   1. Sign up two test users in local Supabase Studio
--   2. Replace placeholder UUIDs with actual auth.users.id values
--   3. Run manually: psql -f database/seeds/002_dev_demo.sql

-- ---------------------------------------------------------------------------
-- IMPORTANT: Replace these placeholders before running
-- ---------------------------------------------------------------------------
-- \set accountant1_user_id '00000000-0000-0000-0000-000000000001'
-- \set accountant2_user_id '00000000-0000-0000-0000-000000000002'

-- Example structure (commented — uncomment and set real UUIDs for local dev):

/*
-- Accountant 1 clients
INSERT INTO public.clients (accountant_id, client_type, first_name, last_name, email)
SELECT a.id, 'individual', 'Jane', 'Smith', 'jane.smith@example.com'
FROM public.accountants a
WHERE a.user_id = :'accountant1_user_id'::uuid
ON CONFLICT DO NOTHING;

INSERT INTO public.clients (accountant_id, client_type, first_name, last_name, email)
SELECT a.id, 'sole_proprietorship', 'Robert', 'Johnson', 'robert.j@example.com'
FROM public.accountants a
WHERE a.user_id = :'accountant1_user_id'::uuid
ON CONFLICT DO NOTHING;

-- Tax profile for Jane Smith
INSERT INTO public.tax_profiles (accountant_id, client_id, tax_year, filing_status, income_types, state_of_residence, onboarding_completed)
SELECT a.id, c.id, 2025, 'single', ARRAY['w2', '1099_nec'], 'CA', true
FROM public.accountants a
JOIN public.clients c ON c.accountant_id = a.id AND c.email = 'jane.smith@example.com'
WHERE a.user_id = :'accountant1_user_id'::uuid
ON CONFLICT (client_id, tax_year) DO NOTHING;

-- Verify tenant isolation: Accountant 2 should see ZERO rows from Accountant 1
-- SELECT count(*) FROM public.clients WHERE accountant_id = public.current_accountant_id();
*/

-- Sprint 1 seed verification query (run as any authenticated accountant):
-- SELECT
--   (SELECT count(*) FROM public.clients) AS visible_clients,
--   public.current_accountant_id() AS my_tenant_id;
