-- Migration: 20260717101100_storage_policies
-- Description: Supabase Storage bucket policies (tenant-isolated paths)
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- Path convention: {accountant_id}/{client_id}/{resource_id}/{filename}
--
-- down:
--   -- Storage policies must be dropped manually in Supabase Studio or via storage API

-- ---------------------------------------------------------------------------
-- Buckets (created via Supabase dashboard or config.toml)
-- Decision: First folder segment = accountant_id for tenant isolation in storage.
-- Mirrors table RLS — accountant can only access their own prefix.
-- ---------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('documents', 'documents', false, 26214400, ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/heic']),
  ('receipts', 'receipts', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/heic']),
  ('exports', 'exports', false, 52428800, ARRAY['application/pdf', 'text/csv']),
  ('avatars', 'avatars', false, 5242880, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO NOTHING;

-- Helper: extract accountant_id from storage path (first folder segment)
CREATE OR REPLACE FUNCTION public.storage_accountant_id(object_name text)
RETURNS uuid
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT NULLIF(split_part(object_name, '/', 1), '')::uuid;
$$;

-- documents bucket policies
CREATE POLICY documents_select_own ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'documents'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

CREATE POLICY documents_insert_own ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'documents'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

CREATE POLICY documents_update_own ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'documents'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

CREATE POLICY documents_delete_own ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'documents'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

-- receipts bucket policies
CREATE POLICY receipts_select_own ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'receipts'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

CREATE POLICY receipts_insert_own ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'receipts'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

CREATE POLICY receipts_delete_own ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'receipts'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

-- exports bucket policies
CREATE POLICY exports_select_own ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'exports'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

CREATE POLICY exports_insert_own ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'exports'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

-- avatars bucket — path: {accountant_id}/avatar.{ext}
CREATE POLICY avatars_select_own ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'avatars'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

CREATE POLICY avatars_insert_own ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

CREATE POLICY avatars_update_own ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );

CREATE POLICY avatars_delete_own ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND public.storage_accountant_id(name) = public.current_accountant_id()
  );
