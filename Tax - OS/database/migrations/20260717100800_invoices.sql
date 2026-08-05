-- Migration: 20260717100800_invoices
-- Description: Client invoicing (freelancer/business clients)
-- Author: TaxOS Engineering
-- Date: 2026-07-17
--
-- down:
--   DROP TABLE IF EXISTS public.invoice_line_items CASCADE;
--   DROP TABLE IF EXISTS public.invoices CASCADE;
--   DROP TABLE IF EXISTS public.billing_contacts CASCADE;

-- ---------------------------------------------------------------------------
-- billing_contacts
-- Decision: Renamed concept from original "clients" table in docs (which was freelancer CRM).
-- In accountant multi-tenant model, taxpayer = clients; invoice recipients = billing_contacts.
-- A billing_contact may belong to a client (business invoicing) or stand alone.
-- ---------------------------------------------------------------------------
CREATE TABLE public.billing_contacts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  accountant_id   uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_id       uuid REFERENCES public.clients (id) ON DELETE SET NULL,
  name            text NOT NULL,
  email           text,
  phone           text,
  address         jsonb,
  deleted_at      timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT billing_contacts_email_format CHECK (
    email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  )
);

CREATE INDEX idx_billing_contacts_accountant ON public.billing_contacts (accountant_id);
CREATE INDEX idx_billing_contacts_client ON public.billing_contacts (client_id)
  WHERE client_id IS NOT NULL;

CREATE TRIGGER billing_contacts_updated_at
  BEFORE UPDATE ON public.billing_contacts
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER billing_contacts_tenant_check
  BEFORE INSERT OR UPDATE ON public.billing_contacts
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_tenant_match();

-- ---------------------------------------------------------------------------
-- invoices
-- ---------------------------------------------------------------------------
CREATE TABLE public.invoices (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  accountant_id     uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  client_id         uuid NOT NULL REFERENCES public.clients (id) ON DELETE CASCADE,
  billing_contact_id uuid REFERENCES public.billing_contacts (id) ON DELETE SET NULL,
  invoice_number    text NOT NULL,
  status            public.invoice_status NOT NULL DEFAULT 'draft',
  issue_date        date NOT NULL,
  due_date          date NOT NULL,
  subtotal          numeric(12,2) NOT NULL,
  tax_amount        numeric(12,2) NOT NULL DEFAULT 0,
  total             numeric(12,2) NOT NULL,
  notes             text,
  pdf_url           text,
  paid_at           timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT invoices_subtotal_non_negative CHECK (subtotal >= 0),
  CONSTRAINT invoices_tax_non_negative CHECK (tax_amount >= 0),
  CONSTRAINT invoices_total_non_negative CHECK (total >= 0),
  CONSTRAINT invoices_due_after_issue CHECK (due_date >= issue_date),
  CONSTRAINT invoices_number_unique_per_accountant UNIQUE (accountant_id, invoice_number)
);

CREATE INDEX idx_invoices_accountant_status ON public.invoices (accountant_id, status);
CREATE INDEX idx_invoices_client ON public.invoices (client_id);
CREATE INDEX idx_invoices_accountant_issue_date ON public.invoices (accountant_id, issue_date DESC);

CREATE TRIGGER invoices_updated_at
  BEFORE UPDATE ON public.invoices
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER invoices_tenant_check
  BEFORE INSERT OR UPDATE ON public.invoices
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_tenant_match();

-- ---------------------------------------------------------------------------
-- invoice_line_items (gap filled from ER diagram)
-- ---------------------------------------------------------------------------
CREATE TABLE public.invoice_line_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id    uuid NOT NULL REFERENCES public.invoices (id) ON DELETE CASCADE,
  accountant_id uuid NOT NULL REFERENCES public.accountants (id) ON DELETE CASCADE,
  description   text NOT NULL,
  quantity      numeric(10,2) NOT NULL DEFAULT 1,
  unit_price    numeric(12,2) NOT NULL,
  amount        numeric(12,2) NOT NULL,
  sort_order    int NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT invoice_line_items_quantity_positive CHECK (quantity > 0),
  CONSTRAINT invoice_line_items_unit_price_non_negative CHECK (unit_price >= 0),
  CONSTRAINT invoice_line_items_amount_non_negative CHECK (amount >= 0)
);

CREATE INDEX idx_invoice_line_items_invoice ON public.invoice_line_items (invoice_id);
CREATE INDEX idx_invoice_line_items_accountant ON public.invoice_line_items (accountant_id);

CREATE TRIGGER invoice_line_items_updated_at
  BEFORE UPDATE ON public.invoice_line_items
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- Line items inherit tenant via invoice — enforce on write
CREATE OR REPLACE FUNCTION public.enforce_invoice_tenant_match()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_invoice_accountant_id uuid;
BEGIN
  SELECT i.accountant_id INTO v_invoice_accountant_id
  FROM public.invoices i
  WHERE i.id = NEW.invoice_id;

  IF v_invoice_accountant_id IS NULL THEN
    RAISE EXCEPTION 'invoice_id % does not exist', NEW.invoice_id;
  END IF;

  IF NEW.accountant_id IS DISTINCT FROM v_invoice_accountant_id THEN
    RAISE EXCEPTION 'invoice_id % does not belong to accountant_id %', NEW.invoice_id, NEW.accountant_id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER invoice_line_items_tenant_check
  BEFORE INSERT OR UPDATE ON public.invoice_line_items
  FOR EACH ROW EXECUTE FUNCTION public.enforce_invoice_tenant_match();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.billing_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_line_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY billing_contacts_select_own ON public.billing_contacts
  FOR SELECT TO authenticated USING (accountant_id = public.current_accountant_id());
CREATE POLICY billing_contacts_insert_own ON public.billing_contacts
  FOR INSERT TO authenticated WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY billing_contacts_update_own ON public.billing_contacts
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY billing_contacts_delete_own ON public.billing_contacts
  FOR DELETE TO authenticated USING (accountant_id = public.current_accountant_id());

CREATE POLICY invoices_select_own ON public.invoices
  FOR SELECT TO authenticated USING (accountant_id = public.current_accountant_id());
CREATE POLICY invoices_insert_own ON public.invoices
  FOR INSERT TO authenticated WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY invoices_update_own ON public.invoices
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY invoices_delete_own ON public.invoices
  FOR DELETE TO authenticated USING (accountant_id = public.current_accountant_id());

CREATE POLICY invoice_line_items_select_own ON public.invoice_line_items
  FOR SELECT TO authenticated USING (accountant_id = public.current_accountant_id());
CREATE POLICY invoice_line_items_insert_own ON public.invoice_line_items
  FOR INSERT TO authenticated WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY invoice_line_items_update_own ON public.invoice_line_items
  FOR UPDATE TO authenticated
  USING (accountant_id = public.current_accountant_id())
  WITH CHECK (accountant_id = public.current_accountant_id());
CREATE POLICY invoice_line_items_delete_own ON public.invoice_line_items
  FOR DELETE TO authenticated USING (accountant_id = public.current_accountant_id());
