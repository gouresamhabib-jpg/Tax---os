-- Central Egyptian tax-obligation catalogue and per-client applicability.
-- The catalogue is a starter reference, not a legal determination or a complete list.
-- Filing deadlines are deliberately not hard-coded until each rule is legally verified.

begin;

create table taxos_prototype.tax_obligation_catalog (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name_ar text not null,
  name_en text not null,
  frequency text not null check (frequency in ('monthly', 'quarterly', 'annual', 'event_based')),
  category text not null check (category in ('income_tax', 'vat', 'withholding', 'payroll', 'other')),
  description_ar text,
  description_en text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table taxos_prototype.client_tax_obligations (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references taxos_prototype.firms(id) on delete restrict,
  client_id uuid not null,
  obligation_id uuid not null references taxos_prototype.tax_obligation_catalog(id) on delete restrict,
  effective_from date not null default current_date,
  effective_to date,
  is_active boolean not null default true,
  notes text,
  created_by_membership_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint client_tax_obligations_client_firm_fk
    foreign key (firm_id, client_id)
    references taxos_prototype.clients(firm_id, id) on delete restrict,
  constraint client_tax_obligations_creator_membership_fk
    foreign key (firm_id, created_by_membership_id)
    references taxos_prototype.firm_memberships(firm_id, id) on delete restrict,
  constraint client_tax_obligations_effective_dates_check
    check (effective_to is null or effective_to >= effective_from),
  constraint client_tax_obligations_unique
    unique (firm_id, client_id, obligation_id)
);

create index client_tax_obligations_firm_client_idx
  on taxos_prototype.client_tax_obligations (firm_id, client_id, is_active);

alter table taxos_prototype.tax_obligation_catalog enable row level security;
alter table taxos_prototype.client_tax_obligations enable row level security;

revoke all on taxos_prototype.tax_obligation_catalog from anon, authenticated;
revoke all on taxos_prototype.client_tax_obligations from anon, authenticated;

grant select on taxos_prototype.tax_obligation_catalog to authenticated;
grant select, insert, update on taxos_prototype.client_tax_obligations to authenticated;

create policy tax_obligation_catalog_read
  on taxos_prototype.tax_obligation_catalog
  for select to authenticated
  using (is_active);

create policy client_tax_obligations_read
  on taxos_prototype.client_tax_obligations
  for select to authenticated
  using (private.is_active_firm_member(firm_id));

create policy client_tax_obligations_insert
  on taxos_prototype.client_tax_obligations
  for insert to authenticated
  with check (
    private.has_firm_role(firm_id, array['owner', 'admin', 'manager'])
    and exists (
      select 1 from taxos_prototype.clients c
      where c.id = client_id and c.firm_id = firm_id and c.archived_at is null
    )
    and exists (
      select 1 from taxos_prototype.firm_memberships m
      where m.id = created_by_membership_id
        and m.firm_id = firm_id
        and m.user_id = (select auth.uid())
        and m.status = 'active'
    )
  );

create policy client_tax_obligations_update
  on taxos_prototype.client_tax_obligations
  for update to authenticated
  using (private.has_firm_role(firm_id, array['owner', 'admin', 'manager']))
  with check (
    private.has_firm_role(firm_id, array['owner', 'admin', 'manager'])
    and exists (
      select 1 from taxos_prototype.clients c
      where c.id = client_id and c.firm_id = firm_id
    )
  );

insert into taxos_prototype.tax_obligation_catalog
  (code, name_ar, name_en, frequency, category, description_ar, description_en)
values
  ('VAT_RETURN', 'إقرار ضريبة القيمة المضافة', 'VAT return', 'monthly', 'vat',
   'يُفعّل فقط للعملاء المسجلين والملزمين بالإقرار. راجع دورية الإقرار المعتمدة للعميل.', 
   'Enable only for clients registered and required to file. Confirm the client-specific filing frequency.'),
  ('WHT_FORM_11', 'نموذج 11 - الخصم والتحصيل تحت حساب الضريبة', 'Form 11 - withholding and collection tax', 'monthly', 'withholding',
   'يُفعّل وفق طبيعة معاملات العميل والتزامه بتقديم النموذج.', 
   'Enable based on the client transaction profile and filing obligation.'),
  ('PAYROLL_TAX', 'ضريبة المرتبات وما في حكمها', 'Payroll tax', 'monthly', 'payroll',
   'يُفعّل للعملاء الذين لديهم مرتبات خاضعة للضريبة، مع مراجعة الالتزامات الدورية المنطبقة.', 
   'Enable for clients with taxable payroll; confirm the applicable periodic obligations.'),
  ('CORPORATE_INCOME_TAX_RETURN', 'الإقرار السنوي لضريبة دخل الأشخاص الاعتبارية', 'Annual corporate income tax return', 'annual', 'income_tax',
   'يُفعّل للأشخاص الاعتبارية الخاضعة، مع تحديد السنة المالية وموعد الاستحقاق وفق الحالة والقانون الساري.', 
   'Enable for taxable legal entities; determine fiscal year and due date under the applicable law.'),
  ('INDIVIDUAL_INCOME_TAX_RETURN', 'الإقرار السنوي لضريبة دخل الأشخاص الطبيعيين', 'Annual individual income tax return', 'annual', 'income_tax',
   'يُفعّل للأشخاص الطبيعيين الملزمين، بعد التحقق من طبيعة النشاط وموقف الإقرار.', 
   'Enable for individuals required to file after confirming activity and filing status.')
on conflict (code) do nothing;

comment on table taxos_prototype.tax_obligation_catalog is
  'Starter catalogue of Egyptian tax obligations. Entries require professional applicability and deadline review.';
comment on table taxos_prototype.client_tax_obligations is
  'Firm-scoped selection of tax obligations applicable to each client; no filing deadlines are inferred here.';

commit;
