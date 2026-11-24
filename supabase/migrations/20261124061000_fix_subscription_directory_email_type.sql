-- Correct the auth.users email return type in the subscription directory RPC.
drop function if exists public.admin_list_merchant_subscriptions(text, integer);
drop function if exists private.admin_list_merchant_subscriptions(text, integer);

create function private.admin_list_merchant_subscriptions(
  p_search text default null,
  p_limit integer default 200
)
returns table (
  merchant_id uuid,
  merchant_name text,
  merchant_slug text,
  merchant_status public.merchant_state,
  owner_user_id uuid,
  owner_name text,
  owner_email text,
  subscription_id uuid,
  plan_key text,
  plan_name text,
  price_usd numeric,
  subscription_status text,
  billing_status text,
  starts_at timestamptz,
  ends_at timestamptz,
  staff_limit integer,
  active_program_limit integer,
  monthly_qr_limit integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_search text := nullif(left(btrim(coalesce(p_search, '')), 120), '');
  v_limit integer := least(greatest(coalesce(p_limit, 200), 1), 500);
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_platform_admin() then
    raise exception 'only super admin can read merchant subscriptions' using errcode = '42501';
  end if;
  return query
  select m.id, m.name, m.slug, m.status, m.owner_user_id,
         pr.full_name, au.email::text,
         s.id, p.plan_key, p.display_name, p.price_usd,
         coalesce(s.status, 'unassigned'), s.billing_status,
         s.starts_at, s.ends_at, p.staff_limit,
         p.active_program_limit, p.monthly_qr_limit
    from public.merchants m
    left join public.profiles pr on pr.id = m.owner_user_id
    left join auth.users au on au.id = m.owner_user_id
    left join public.merchant_subscriptions s on s.merchant_id = m.id
    left join public.subscription_plans p on p.plan_key = s.plan_key
   where v_search is null
      or m.name ilike '%' || v_search || '%'
      or m.slug ilike '%' || v_search || '%'
      or coalesce(au.email::text, '') ilike '%' || v_search || '%'
      or m.owner_user_id::text ilike '%' || v_search || '%'
   order by m.created_at desc
   limit v_limit;
end;
$$;

create function public.admin_list_merchant_subscriptions(
  p_search text default null,
  p_limit integer default 200
)
returns table (
  merchant_id uuid,
  merchant_name text,
  merchant_slug text,
  merchant_status public.merchant_state,
  owner_user_id uuid,
  owner_name text,
  owner_email text,
  subscription_id uuid,
  plan_key text,
  plan_name text,
  price_usd numeric,
  subscription_status text,
  billing_status text,
  starts_at timestamptz,
  ends_at timestamptz,
  staff_limit integer,
  active_program_limit integer,
  monthly_qr_limit integer
)
language sql
security invoker
set search_path = ''
as $$ select * from private.admin_list_merchant_subscriptions($1, $2); $$;

revoke all on function private.admin_list_merchant_subscriptions(text,integer) from public, anon, authenticated;
revoke all on function public.admin_list_merchant_subscriptions(text,integer) from public, anon;
grant execute on function private.admin_list_merchant_subscriptions(text,integer) to authenticated;
grant execute on function public.admin_list_merchant_subscriptions(text,integer) to authenticated;
