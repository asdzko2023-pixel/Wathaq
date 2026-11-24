-- Restricted, read-only directory of merchant staff for platform administrators.
-- Exposes no auth.users data or direct write access.

create or replace function private.admin_list_merchant_staff(
  p_search text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns table (
  merchant_id uuid,
  merchant_name text,
  user_id uuid,
  role text,
  permissions text[],
  is_active boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_search text := nullif(left(btrim(coalesce(p_search, '')), 100), '');
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 200);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 1000000);
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_platform_admin() then
    raise exception 'platform administrator required' using errcode = '42501';
  end if;
  return query
  select mm.merchant_id, m.name, mm.user_id, mm.role, mm.permissions, mm.is_active, mm.created_at
    from public.merchant_members mm
    join public.merchants m on m.id = mm.merchant_id
   where v_search is null
      or m.name ilike '%' || v_search || '%'
      or mm.user_id::text ilike '%' || v_search || '%'
      or mm.role ilike '%' || v_search || '%'
   order by mm.created_at desc, mm.merchant_id, mm.user_id
   limit v_limit offset v_offset;
end;
$function$;

revoke all on function private.admin_list_merchant_staff(text, integer, integer) from public;
revoke all on function private.admin_list_merchant_staff(text, integer, integer) from anon;
grant execute on function private.admin_list_merchant_staff(text, integer, integer) to authenticated;

create or replace function public.admin_list_merchant_staff(
  p_search text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns table (
  merchant_id uuid,
  merchant_name text,
  user_id uuid,
  role text,
  permissions text[],
  is_active boolean,
  created_at timestamptz
)
language sql
security invoker
set search_path = ''
as $function$
  select * from private.admin_list_merchant_staff($1, $2, $3);
$function$;

revoke all on function public.admin_list_merchant_staff(text, integer, integer) from public;
revoke all on function public.admin_list_merchant_staff(text, integer, integer) from anon;
grant execute on function public.admin_list_merchant_staff(text, integer, integer) to authenticated;
