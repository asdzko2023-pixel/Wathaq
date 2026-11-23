-- Let an authenticated merchant owner read only their own current subscription.
create or replace function private.merchant_get_my_subscriptions()
returns table (
  merchant_id uuid,
  merchant_name text,
  plan_key text,
  plan_name text,
  price_usd numeric,
  subscription_status text,
  billing_status text,
  starts_at timestamptz,
  ends_at timestamptz,
  staff_limit integer,
  active_program_limit integer,
  monthly_qr_limit integer,
  live_features jsonb,
  planned_features jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  return query
  select m.id, m.name, s.plan_key, p.display_name, p.price_usd,
         s.status, s.billing_status, s.starts_at, s.ends_at,
         p.staff_limit, p.active_program_limit, p.monthly_qr_limit,
         p.live_features, p.planned_features
    from public.merchants m
    join public.merchant_subscriptions s on s.merchant_id = m.id
    join public.subscription_plans p on p.plan_key = s.plan_key
   where m.owner_user_id = v_user_id
   order by m.created_at desc;
end;
$$;

create or replace function public.merchant_get_my_subscriptions()
returns table (
  merchant_id uuid,
  merchant_name text,
  plan_key text,
  plan_name text,
  price_usd numeric,
  subscription_status text,
  billing_status text,
  starts_at timestamptz,
  ends_at timestamptz,
  staff_limit integer,
  active_program_limit integer,
  monthly_qr_limit integer,
  live_features jsonb,
  planned_features jsonb
)
language sql
security invoker
set search_path = ''
as $$ select * from private.merchant_get_my_subscriptions(); $$;

revoke all on function private.merchant_get_my_subscriptions() from public, anon, authenticated;
revoke all on function public.merchant_get_my_subscriptions() from public, anon;
grant execute on function private.merchant_get_my_subscriptions() to authenticated;
grant execute on function public.merchant_get_my_subscriptions() to authenticated;
