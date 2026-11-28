-- Run after 20261128120000_private_rls_helpers.sql and
-- 20261128130000_firm_member_directory.sql on a disposable Supabase database.

do $test$
declare
  v_function record;
begin
  select p.prosecdef, p.provolatile
  into v_function
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'taxos_prototype'
    and p.proname = 'list_firm_members'
    and pg_get_function_identity_arguments(p.oid) = 'p_firm_id uuid';

  if not found or not v_function.prosecdef or v_function.provolatile <> 's' then
    raise exception 'Member directory must exist as a stable SECURITY DEFINER function';
  end if;

  if not has_function_privilege('authenticated', 'taxos_prototype.list_firm_members(uuid)', 'EXECUTE') then
    raise exception 'authenticated must be able to call the member directory';
  end if;

  if has_function_privilege('anon', 'taxos_prototype.list_firm_members(uuid)', 'EXECUTE') then
    raise exception 'anon must not be able to call the member directory';
  end if;
end
$test$;
