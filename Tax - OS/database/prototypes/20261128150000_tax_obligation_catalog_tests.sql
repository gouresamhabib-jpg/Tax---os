-- Structural checks for 20261128150000_tax_obligation_catalog.sql.
-- Run against a disposable Supabase-compatible database after applying the migration.
do $test$
declare
  v_count integer;
begin
  select count(*) into v_count
  from taxos_prototype.tax_obligation_catalog
  where code in ('VAT_RETURN','WHT_FORM_11','PAYROLL_TAX',
    'CORPORATE_INCOME_TAX_RETURN','INDIVIDUAL_INCOME_TAX_RETURN');
  if v_count <> 5 then
    raise exception 'Expected five starter catalogue entries; found %', v_count;
  end if;

  if not (select relrowsecurity from pg_class
    where oid = 'taxos_prototype.tax_obligation_catalog'::regclass) then
    raise exception 'Catalogue RLS is not enabled';
  end if;
  if not (select relrowsecurity from pg_class
    where oid = 'taxos_prototype.client_tax_obligations'::regclass) then
    raise exception 'Client applicability RLS is not enabled';
  end if;

  if has_table_privilege('anon', 'taxos_prototype.client_tax_obligations', 'SELECT')
     or has_table_privilege('anon', 'taxos_prototype.client_tax_obligations', 'INSERT') then
    raise exception 'anon must not access client obligation assignments';
  end if;

  if not has_table_privilege('authenticated', 'taxos_prototype.tax_obligation_catalog', 'SELECT')
     or not has_table_privilege('authenticated', 'taxos_prototype.client_tax_obligations', 'SELECT') then
    raise exception 'authenticated is missing required read access';
  end if;
end
$test$;
