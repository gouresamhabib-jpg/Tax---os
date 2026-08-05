-- Migration: 20260717100700_expenses_documents
-- Description: Client expenses and document vault (tenant-scoped)
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- down:
--   ALTER TABLE public.return_documents DROP CONSTRAINT IF EXISTS return_documents_document_id_fkey;
--   DROP TRIGGER IF EXISTS documents_tenant_check ON public.documents;
--   DROP TRIGGER IF EXISTS expenses_tenant_check ON public.expenses;
--   DROP TABLE IF EXISTS public.documents CASCADE;
--   DROP TABLE IF EXISTS public.expenses CASCADE;

-- ---------------------------------------------------------------------------
-- expenses
-- Decision: Scoped to client (not accountant globally) because expenses belong to a taxpayer.
-- tax_return_id optional — linked when included on a return.
-- ---------------------------------------------------------------------------
CREATE TABLE public.expenses (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  accountant_id   uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_id       uuid NOT NULL REFERENCES public.clients (id) ON DELETE CASCADE,
  category_id     uuid NOT NULL REFERENCES public.expense_categories (id),
  amount          numeric(12,2) NOT NULL,
  expense_date    date NOT NULL,
  description     text,
  merchant        text,
  is_business     boolean NOT NULL DEFAULT true,
  receipt_url     text,
  tax_return_id   uuid REFERENCES public.tax_returns (id) ON DELETE SET NULL,
  synced_at       timestamptz,
  deleted_at      timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT expenses_amount_positive CHECK (amount > 0),
  CONSTRAINT expenses_date_not_future CHECK (expense_date <= CURRENT_DATE + interval '1 day')
);

CREATE INDEX idx_expenses_accountant_date ON public.expenses (accountant_id, expense_date DESC);
CREATE INDEX idx_expenses_accountant_category ON public.expenses (accountant_id, category_id);
CREATE INDEX idx_expenses_client_date ON public.expenses (client_id, expense_date DESC);
CREATE INDEX idx_expenses_accountant_active ON public.expenses (accountant_id)
  WHERE deleted_at IS NULL;
CREATE INDEX idx_expenses_return ON public.expenses (tax_return_id) WHERE tax_return_id IS NOT NULL;

CREATE TRIGGER expenses_updated_at
  BEFORE UPDATE ON public.expenses
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER expenses_tenant_check
  BEFORE INSERT OR UPDATE ON public.expenses
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_tenant_match();

-- ---------------------------------------------------------------------------
-- documents
-- Storage path convention: {accountant_id}/{client_id}/{document_id}/{filename}
-- ---------------------------------------------------------------------------
CREATE TABLE public.documents (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  accountant_id   uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_id       uuid NOT NULL REFERENCES public.clients (id) ON DELETE CASCADE,
  category_id     uuid NOT NULL REFERENCES public.document_categories (id),
  file_name       text NOT NULL,
  storage_path    text NOT NULL,
  file_size       bigint NOT NULL,
  mime_type       text NOT NULL,
  tags            text[] NOT NULL DEFAULT '{}',
  tax_return_id   uuid REFERENCES public.tax_returns (id) ON DELETE SET NULL,
  deleted_at      timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT documents_file_size_positive CHECK (file_size > 0),
  CONSTRAINT documents_mime_type_format CHECK (mime_type ~ '^[a-z]+/[a-z0-9.+-]+$')
);

CREATE INDEX idx_documents_accountant ON public.documents (accountant_id);
CREATE INDEX idx_documents_client ON public.documents (client_id);
CREATE INDEX idx_documents_accountant_category ON public.documents (accountant_id, category_id);
CREATE INDEX idx_documents_accountant_active ON public.documents (accountant_id)
  WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_tags ON public.documents USING gin (tags);

CREATE TRIGGER documents_updated_at
  BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER documents_tenant_check
  BEFORE INSERT OR UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_tenant_match();

-- Deferred FK from return_documents → documents
ALTER TABLE public.return_documents
  ADD CONSTRAINT return_documents_document_id_fkey
  FOREIGN KEY (document_id) REFERENCES public.documents (id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY expenses_select_own ON public.expenses
  FOR SELECT TO authenticated USING (accountant_id = public.current_accountant_id());
CREATE POLICY expenses_insert_own ON public.expenses
  FOR INSERT TO authenticated WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY expenses_update_own ON public.expenses
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY expenses_delete_own ON public.expenses
  FOR DELETE TO authenticated USING (accountant_id = public.current_accountant_id());

CREATE POLICY documents_select_own ON public.documents
  FOR SELECT TO authenticated USING (accountant_id = public.current_accountant_id());
CREATE POLICY documents_insert_own ON public.documents
  FOR INSERT TO authenticated WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY documents_update_own ON public.documents
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY documents_delete_own ON public.documents
  FOR DELETE TO authenticated USING (accountant_id = public.current_accountant_id());
