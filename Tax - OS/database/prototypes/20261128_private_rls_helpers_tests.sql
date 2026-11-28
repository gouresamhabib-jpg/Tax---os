-- Run after 20261128_private_rls_helpers.sql in a disposable Supabase-compatible database.
-- These checks verify function placement and the grants needed by RLS policies.

do $test$
declare
  v_function_count integer;
  v_policy_count integer;
begin
  select count(*) into v_function_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private'
    and p.proname in (
      'has_firm_role',
      'is_active_firm_member',
      'is_active_firm_membership',
      'is_firm_manager'
    )
    and p.prosecdef;

  if v_function_count <> 4 then
    raise exception 'Expected 4 SECURITY DEFINER helpers in private schema; found %', v_function_count;
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'taxos_prototype'
      and p.proname in (
        'has_firm_role',
        'is_active_firm_member',
        'is_active_firm_membership',
        'is_firm_manager'
      )
  ) then
    raise exception 'A helper remains in the PostgREST-facing taxos_prototype schema';
  end if;

  if not has_schema_privilege('authenticated', 'private', 'USAGE') then
    raise exception 'authenticated requires USAGE on private for RLS helper calls';
  end if;

  if has_schema_privilege('anon', 'private', 'USAGE') then
    raise exception 'anon must not have USAGE on private';
  end if;

  if not has_function_privilege('authenticated', 'private.has_firm_role(uuid,text[])', 'EXECUTE')
     or not has_function_privilege('authenticated', 'private.is_active_firm_member(uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'private.is_active_firm_membership(uuid,uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'private.is_firm_manager(uuid)', 'EXECUTE') then
    raise exception 'authenticated is missing EXECUTE on one or more RLS helpers';
  end if;

  if has_function_privilege('anon', 'private.has_firm_role(uuid,text[])', 'EXECUTE')
     or has_function_privilege('anon', 'private.is_active_firm_member(uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'private.is_active_firm_membership(uuid,uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'private.is_firm_manager(uuid)', 'EXECUTE') then
    raise exception 'anon must not be able to execute private RLS helpers';
  end if;

  select count(*) into v_policy_count
  from pg_policy pol
  join pg_class c on c.oid = pol.polrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'taxos_prototype'
    and (
      pg_get_expr(pol.polqual, pol.polrelid) like '%private.%'
      or pg_get_expr(pol.polwithcheck, pol.polrelid) like '%private.%'
    );

  if v_policy_count < 1 then
    raise exception 'Expected existing RLS policies to retain references to moved helper functions';
  end if;
end
$test$;
