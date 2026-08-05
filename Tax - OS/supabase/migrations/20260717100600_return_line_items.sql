-- Migration: 20260717100600_return_line_items
-- Description: Income, deduction, credit line items and return-document junction
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- down:
--   DROP TABLE IF EXISTS public.return_documents CASCADE;
--   DROP TABLE IF EXISTS public.credit_entries CASCADE;
--   DROP TABLE IF EXISTS public.deduction_entries CASCADE;
--   DROP TABLE IF EXISTS public.income_entries CASCADE;

-- ---------------------------------------------------------------------------
-- income_entries
-- Decision: accountant_id denormalized for fast RLS (no JOIN to tax_returns on every scan).
-- details JSONB holds type-specific fields (W-2 box values, Schedule C line items, etc.).
-- ---------------------------------------------------------------------------
CREATE TABLE public.income_entries (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tax_return_id    uuid NOT NULL REFERENCES public.tax_returns (id) ON DELETE CASCADE,
  accountant_id    uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_id        uuid NOT NULL REFERENCES public.clients (id) ON DELETE CASCADE,
  income_type      public.income_type NOT NULL,
  source_name      text,
  gross_amount     numeric(12,2) NOT NULL,
  federal_withheld numeric(12,2) NOT NULL DEFAULT 0,
  state_withheld   numeric(12,2) NOT NULL DEFAULT 0,
  details          jsonb NOT NULL DEFAULT '{}',
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT income_entries_gross_positive CHECK (gross_amount >= 0),
  CONSTRAINT income_entries_withheld_non_negative CHECK (
    federal_withheld >= 0 AND state_withheld >= 0
  )
);

CREATE INDEX idx_income_entries_return ON public.income_entries (tax_return_id);
CREATE INDEX idx_income_entries_accountant ON public.income_entries (accountant_id);
CREATE INDEX idx_income_entries_client ON public.income_entries (client_id);

CREATE TRIGGER income_entries_updated_at
  BEFORE UPDATE ON public.income_entries
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER income_entries_tenant_check
  BEFORE INSERT OR UPDATE ON public.income_entries
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_tenant_match();

-- ---------------------------------------------------------------------------
-- deduction_entries
-- ---------------------------------------------------------------------------
CREATE TABLE public.deduction_entries (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tax_return_id   uuid NOT NULL REFERENCES public.tax_returns (id) ON DELETE CASCADE,
  accountant_id   uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_id       uuid NOT NULL REFERENCES public.clients (id) ON DELETE CASCADE,
  deduction_type  public.deduction_type NOT NULL,
  amount          numeric(12,2) NOT NULL,
  description     text,
  details         jsonb NOT NULL DEFAULT '{}',
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT deduction_entries_amount_positive CHECK (amount > 0)
);

CREATE INDEX idx_deduction_entries_return ON public.deduction_entries (tax_return_id);
CREATE INDEX idx_deduction_entries_accountant ON public.deduction_entries (accountant_id);

CREATE TRIGGER deduction_entries_updated_at
  BEFORE UPDATE ON public.deduction_entries
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER deduction_entries_tenant_check
  BEFORE INSERT OR UPDATE ON public.deduction_entries
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_tenant_match();

-- ---------------------------------------------------------------------------
-- credit_entries (gap filled from ER diagram)
-- ---------------------------------------------------------------------------
CREATE TABLE public.credit_entries (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tax_return_id   uuid NOT NULL REFERENCES public.tax_returns (id) ON DELETE CASCADE,
  accountant_id   uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_id       uuid NOT NULL REFERENCES public.clients (id) ON DELETE CASCADE,
  credit_type     public.credit_type NOT NULL,
  amount          numeric(12,2) NOT NULL,
  description     text,
  details         jsonb NOT NULL DEFAULT '{}',
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT credit_entries_amount_positive CHECK (amount > 0)
);

CREATE INDEX idx_credit_entries_return ON public.credit_entries (tax_return_id);
CREATE INDEX idx_credit_entries_accountant ON public.credit_entries (accountant_id);

CREATE TRIGGER credit_entries_updated_at
  BEFORE UPDATE ON public.credit_entries
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER credit_entries_tenant_check
  BEFORE INSERT OR UPDATE ON public.credit_entries
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_tenant_match();

-- ---------------------------------------------------------------------------
-- return_documents — N:M junction between returns and documents
-- Decision: Allows one document attached to multiple returns (amended filings).
-- ---------------------------------------------------------------------------
CREATE TABLE public.return_documents (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tax_return_id   uuid NOT NULL REFERENCES public.tax_returns (id) ON DELETE CASCADE,
  document_id     uuid NOT NULL,  -- FK added after documents table exists
  accountant_id   uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_id       uuid NOT NULL REFERENCES public.clients (id) ON DELETE CASCADE,
  line_item_ref   text,
  created_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT return_documents_unique UNIQUE (tax_return_id, document_id)
);

CREATE INDEX idx_return_documents_return ON public.return_documents (tax_return_id);
CREATE INDEX idx_return_documents_document ON public.return_documents (document_id);
CREATE INDEX idx_return_documents_accountant ON public.return_documents (accountant_id);

CREATE TRIGGER return_documents_tenant_check
  BEFORE INSERT OR UPDATE ON public.return_documents
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_tenant_match();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.income_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deduction_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.return_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY income_entries_select_own ON public.income_entries
  FOR SELECT TO authenticated USING (accountant_id = public.current_accountant_id());
CREATE POLICY income_entries_insert_own ON public.income_entries
  FOR INSERT TO authenticated WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY income_entries_update_own ON public.income_entries
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY income_entries_delete_own ON public.income_entries
  FOR DELETE TO authenticated USING (accountant_id = public.current_accountant_id());

CREATE POLICY deduction_entries_select_own ON public.deduction_entries
  FOR SELECT TO authenticated USING (accountant_id = public.current_accountant_id());
CREATE POLICY deduction_entries_insert_own ON public.deduction_entries
  FOR INSERT TO authenticated WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY deduction_entries_update_own ON public.deduction_entries
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY deduction_entries_delete_own ON public.deduction_entries
  FOR DELETE TO authenticated USING (accountant_id = public.current_accountant_id());

CREATE POLICY credit_entries_select_own ON public.credit_entries
  FOR SELECT TO authenticated USING (accountant_id = public.current_accountant_id());
CREATE POLICY credit_entries_insert_own ON public.credit_entries
  FOR INSERT TO authenticated WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY credit_entries_update_own ON public.credit_entries
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY credit_entries_delete_own ON public.credit_entries
  FOR DELETE TO authenticated USING (accountant_id = public.current_accountant_id());

CREATE POLICY return_documents_select_own ON public.return_documents
  FOR SELECT TO authenticated USING (accountant_id = public.current_accountant_id());
CREATE POLICY return_documents_insert_own ON public.return_documents
  FOR INSERT TO authenticated WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY return_documents_delete_own ON public.return_documents
  FOR DELETE TO authenticated USING (accountant_id = public.current_accountant_id());
