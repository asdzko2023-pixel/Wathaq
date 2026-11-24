-- Subscription history RPC and expired-status projection.
create or replace function private.admin_list_merchant_subscriptions(
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
         case when s.status = 'active' and s.ends_at <= now() then 'expired'
              else coalesce(s.status, 'unassigned') end,
         s.billing_status, s.starts_at, s.ends_at,
         p.staff_limit, p.active_program_limit, p.monthly_qr_limit
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

create or replace function private.admin_list_subscription_history(
  p_merchant_id uuid,
  p_limit integer default 100
)
returns table (
  history_id uuid,
  action text,
  from_plan_name text,
  to_plan_name text,
  from_status text,
  to_status text,
  from_ends_at timestamptz,
  to_ends_at timestamptz,
  billing_status text,
  note text,
  actor_user_id uuid,
  actor_name text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit,100),1),200);
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_platform_admin() then
    raise exception 'only super admin can read subscription history' using errcode = '42501';
  end if;
  if p_merchant_id is null then
    raise exception 'merchant id required' using errcode = '22023';
  end if;
  return query
  select h.id, h.action, fp.display_name, tp.display_name,
         h.from_status, h.to_status, h.from_ends_at, h.to_ends_at,
         h.billing_status, h.note, h.actor_user_id, pr.full_name, h.created_at
    from public.subscription_history h
    left join public.subscription_plans fp on fp.plan_key = h.from_plan_key
    left join public.subscription_plans tp on tp.plan_key = h.to_plan_key
    left join public.profiles pr on pr.id = h.actor_user_id
   where h.merchant_id = p_merchant_id
   order by h.created_at desc
   limit v_limit;
end;
$$;

create or replace function public.admin_list_subscription_history(
  p_merchant_id uuid,
  p_limit integer default 100
)
returns table (
  history_id uuid,
  action text,
  from_plan_name text,
  to_plan_name text,
  from_status text,
  to_status text,
  from_ends_at timestamptz,
  to_ends_at timestamptz,
  billing_status text,
  note text,
  actor_user_id uuid,
  actor_name text,
  created_at timestamptz
)
language sql
security invoker
set search_path = ''
as $$ select * from private.admin_list_subscription_history($1,$2); $$;

revoke all on function private.admin_list_subscription_history(uuid,integer) from public, anon, authenticated;
revoke all on function public.admin_list_subscription_history(uuid,integer) from public, anon;
grant execute on function private.admin_list_subscription_history(uuid,integer) to authenticated;
grant execute on function public.admin_list_subscription_history(uuid,integer) to authenticated;
