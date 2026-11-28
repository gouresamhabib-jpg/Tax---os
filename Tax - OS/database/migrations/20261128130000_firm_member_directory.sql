-- Firm-scoped member directory for the authenticated workspace UI.
-- Exposes only active members of a firm the caller already belongs to.
-- This migration is reviewed in GitHub only; it is not applied to hosted staging.

begin;

create or replace function taxos_prototype.list_firm_members(p_firm_id uuid)
returns table (
  membership_id uuid,
  user_id uuid,
  display_name text,
  email text,
  role text,
  status text
)
language plpgsql
stable
security definer
set search_path = pg_catalog, auth, taxos_prototype, private
as $function$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not private.is_active_firm_member(p_firm_id) then
    raise exception 'Active firm membership required' using errcode = '42501';
  end if;

  return query
  select
    membership.id,
    membership.user_id,
    coalesce(
      nullif(btrim(auth_user.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(auth_user.raw_user_meta_data ->> 'name'), ''),
      auth_user.email
    )::text,
    auth_user.email::text,
    membership.role,
    membership.status
  from taxos_prototype.firm_memberships as membership
  join auth.users as auth_user on auth_user.id = membership.user_id
  where membership.firm_id = p_firm_id
    and membership.status = 'active'
  order by
    case membership.role when 'owner' then 0 when 'admin' then 1 when 'manager' then 2 else 3 end,
    lower(coalesce(auth_user.raw_user_meta_data ->> 'full_name', auth_user.email));
end;
$function$;

revoke all on function taxos_prototype.list_firm_members(uuid) from public, anon;
grant execute on function taxos_prototype.list_firm_members(uuid) to authenticated;

comment on function taxos_prototype.list_firm_members(uuid) is
  'Returns only active members of a firm after verifying the caller is an active member.';

commit;
