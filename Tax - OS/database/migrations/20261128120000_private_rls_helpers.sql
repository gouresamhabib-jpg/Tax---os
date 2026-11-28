-- Move RLS-only SECURITY DEFINER helpers out of the PostgREST-exposed schema.
-- Existing policy dependencies follow the function OIDs when ALTER FUNCTION SET SCHEMA runs.
-- Keep authenticated EXECUTE because RLS evaluates these helpers as the calling role.
-- The private schema must NOT be added to PostgREST's exposed schemas.

begin;

create schema if not exists private;

revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
revoke create on schema private from authenticated;

alter function taxos_prototype.has_firm_role(uuid, text[]) set schema private;
alter function taxos_prototype.is_active_firm_member(uuid) set schema private;
alter function taxos_prototype.is_active_firm_membership(uuid, uuid) set schema private;

-- has_firm_role now lives in private; update the manager helper before moving it.
create or replace function taxos_prototype.is_firm_manager(p_firm_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, private, taxos_prototype, auth
as $function$
  select private.has_firm_role(
    p_firm_id,
    array['owner', 'admin', 'manager']
  );
$function$;

alter function taxos_prototype.is_firm_manager(uuid) set schema private;

revoke all on function private.has_firm_role(uuid, text[]) from public, anon;
revoke all on function private.is_active_firm_member(uuid) from public, anon;
revoke all on function private.is_active_firm_membership(uuid, uuid) from public, anon;
revoke all on function private.is_firm_manager(uuid) from public, anon;

grant execute on function private.has_firm_role(uuid, text[]) to authenticated;
grant execute on function private.is_active_firm_member(uuid) to authenticated;
grant execute on function private.is_active_firm_membership(uuid, uuid) to authenticated;
grant execute on function private.is_firm_manager(uuid) to authenticated;

comment on schema private is
  'Internal database helpers. Do not expose this schema through the Supabase Data API.';

commit;
