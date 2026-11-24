-- Test-only compatibility shim for the isolated PostgreSQL prototype workflow.
-- This is NOT Supabase Auth and must never be deployed to an application database.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;

CREATE SCHEMA auth;
CREATE TABLE auth.users (
  id uuid PRIMARY KEY,
  email text UNIQUE,
  email_confirmed_at timestamptz
);

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

GRANT USAGE ON SCHEMA auth TO authenticated;

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
  ('11111111-1111-4111-8111-111111111111', 'taxos-user-a@example.com', now()),
  ('22222222-2222-4222-8222-222222222222', 'taxos-user-b@example.com', now()),
  ('33333333-3333-4333-8333-333333333333', 'taxos-user-c@example.com', now());
