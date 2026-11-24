-- Keep the exposed PostgREST endpoint SECURITY INVOKER.
-- The privileged implementation lives in the non-exposed private schema.

create or replace function private.admin_list_user_profiles(
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  user_id uuid,
  full_name text,
  preferred_locale text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_search text := nullif(left(btrim(coalesce(p_search, '')), 100), '');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 1000000);
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_platform_admin() then
    raise exception 'platform administrator required' using errcode = '42501';
  end if;
  return query
  select p.id, nullif(btrim(p.full_name), ''), p.preferred_locale, p.created_at
    from public.profiles as p
   where v_search is null
      or coalesce(p.full_name, '') ilike '%' || v_search || '%'
      or p.id::text ilike '%' || v_search || '%'
   order by p.created_at desc, p.id
   limit v_limit offset v_offset;
end;
$function$;

revoke all on function private.admin_list_user_profiles(text, integer, integer) from public;
revoke all on function private.admin_list_user_profiles(text, integer, integer) from anon;
grant execute on function private.admin_list_user_profiles(text, integer, integer) to authenticated;

create or replace function public.admin_list_user_profiles(
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  user_id uuid,
  full_name text,
  preferred_locale text,
  created_at timestamptz
)
language sql
security invoker
set search_path = ''
as $function$
  select * from private.admin_list_user_profiles($1, $2, $3);
$function$;

revoke all on function public.admin_list_user_profiles(text, integer, integer) from public;
revoke all on function public.admin_list_user_profiles(text, integer, integer) from anon;
grant execute on function public.admin_list_user_profiles(text, integer, integer) to authenticated;
