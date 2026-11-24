-- Business plan: owner-scoped advanced analytics without exposing customer identities.
create or replace function private.merchant_get_advanced_analytics(
  p_merchant_id uuid,
  p_days integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_timezone text;
  v_merchant_status text;
  v_subscription_status text;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_live_features jsonb;
  v_start_date date;
  v_today date;
  v_start_at timestamptz;
  v_end_at timestamptz;
  v_report jsonb;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_merchant_id is null then
    raise exception 'merchant is required' using errcode = '22023';
  end if;
  if p_days is null or p_days < 7 or p_days > 90 then
    raise exception 'period must be between 7 and 90 days' using errcode = '22023';
  end if;

  select m.timezone, m.status::text, s.status, s.starts_at, s.ends_at, p.live_features
    into v_timezone, v_merchant_status, v_subscription_status, v_starts_at, v_ends_at, v_live_features
    from public.merchants m
    join public.merchant_subscriptions s on s.merchant_id = m.id
    join public.subscription_plans p on p.plan_key = s.plan_key
   where m.id = p_merchant_id
     and m.owner_user_id = v_actor;

  if not found then
    raise exception 'merchant not found or access denied' using errcode = '42501';
  end if;
  if v_merchant_status <> 'active' then
    raise exception 'merchant must be active for advanced analytics' using errcode = '42501';
  end if;
  if v_subscription_status <> 'active'
     or v_starts_at > now()
     or v_ends_at <= now() then
    raise exception 'an active, current subscription is required' using errcode = '42501';
  end if;
  if not (coalesce(v_live_features, '[]'::jsonb) @> '["advanced_analytics"]'::jsonb) then
    raise exception 'advanced analytics is not included in the current subscription plan' using errcode = '42501';
  end if;

  v_today := (now() at time zone v_timezone)::date;
  v_start_date := v_today - (p_days - 1);
  v_start_at := v_start_date::timestamp at time zone v_timezone;
  v_end_at := (v_today + 1)::timestamp at time zone v_timezone;

  with ledger_period as (
    select ll.*
      from public.loyalty_ledger ll
     where ll.merchant_id = p_merchant_id
       and ll.created_at >= v_start_at
       and ll.created_at < v_end_at
  ),
  daily as (
    select
      (ll.created_at at time zone v_timezone)::date as day,
      count(*)::bigint as ledger_entries,
      coalesce(sum(ll.points_delta) filter (where ll.kind = 'earn'),0)::bigint as points_earned,
      coalesce(sum(-ll.points_delta) filter (where ll.kind = 'redeem'),0)::bigint as points_redeemed
    from ledger_period ll
    group by (ll.created_at at time zone v_timezone)::date
  ),
  trend as (
    select
      g.day::date as day,
      coalesce(d.ledger_entries,0)::bigint as ledger_entries,
      coalesce(d.points_earned,0)::bigint as points_earned,
      coalesce(d.points_redeemed,0)::bigint as points_redeemed
    from generate_series(v_start_date::timestamp,v_today::timestamp,interval '1 day') g(day)
    left join daily d on d.day = g.day::date
    order by g.day
  ),
  by_kind as (
    select
      ll.kind::text as kind,
      count(*)::bigint as entries,
      coalesce(sum(ll.points_delta) filter (where ll.kind = 'earn'),0)::bigint as points_earned,
      coalesce(sum(-ll.points_delta) filter (where ll.kind = 'redeem'),0)::bigint as points_redeemed
    from ledger_period ll
    group by ll.kind
    order by count(*) desc, ll.kind::text
  ),
  program_accounts as (
    select
      la.program_id,
      count(*)::bigint as accounts_total,
      count(*) filter (where la.joined_at >= v_start_at)::bigint as new_accounts
    from public.loyalty_accounts la
    where la.merchant_id = p_merchant_id
    group by la.program_id
  ),
  program_ledger as (
    select
      ll.program_id,
      count(*)::bigint as ledger_entries,
      coalesce(sum(ll.points_delta) filter (where ll.kind = 'earn'),0)::bigint as points_earned,
      coalesce(sum(-ll.points_delta) filter (where ll.kind = 'redeem'),0)::bigint as points_redeemed
    from ledger_period ll
    group by ll.program_id
  ),
  program_activity as (
    select
      lp.id,
      lp.name,
      lp.kind::text as program_kind,
      lp.state::text as state,
      coalesce(pa.accounts_total,0)::bigint as accounts_total,
      coalesce(pa.new_accounts,0)::bigint as new_accounts,
      coalesce(pl.ledger_entries,0)::bigint as ledger_entries,
      coalesce(pl.points_earned,0)::bigint as points_earned,
      coalesce(pl.points_redeemed,0)::bigint as points_redeemed
    from public.loyalty_programs lp
    left join program_accounts pa on pa.program_id = lp.id
    left join program_ledger pl on pl.program_id = lp.id
    where lp.merchant_id = p_merchant_id
  ),
  summary as (
    select
      count(*)::bigint as ledger_entries,
      coalesce(sum(points_delta) filter (where kind = 'earn'),0)::bigint as points_earned,
      coalesce(sum(-points_delta) filter (where kind = 'redeem'),0)::bigint as points_redeemed
    from ledger_period
  )
  select jsonb_build_object(
    'period_days',p_days,
    'timezone',v_timezone,
    'period_start',v_start_at,
    'period_end',v_end_at,
    'ledger_entries',s.ledger_entries,
    'points_earned',s.points_earned,
    'points_redeemed',s.points_redeemed,
    'new_accounts',(
      select count(*)::bigint
        from public.loyalty_accounts a
       where a.merchant_id=p_merchant_id
         and a.joined_at >= v_start_at
         and a.joined_at < v_end_at
    ),
    'active_accounts',(
      select count(*)::bigint
        from public.loyalty_accounts a
       where a.merchant_id=p_merchant_id
         and a.last_activity_at >= v_start_at
         and a.last_activity_at < v_end_at
    ),
    'trend',coalesce((select jsonb_agg(to_jsonb(t) order by t.day) from trend t),'[]'::jsonb),
    'ledger_by_kind',coalesce((select jsonb_agg(to_jsonb(k) order by k.entries desc,k.kind) from by_kind k),'[]'::jsonb),
    'top_programs',coalesce((
      select jsonb_agg(to_jsonb(x) order by x.points_earned desc,x.accounts_total desc,x.name)
      from (select * from program_activity order by points_earned desc,accounts_total desc,name limit 10) x
    ),'[]'::jsonb)
  )
  into v_report
  from summary s;

  insert into public.audit_events(
    actor_user_id,merchant_id,action,entity_type,entity_id,details
  ) values (
    v_actor,p_merchant_id,'merchant.advanced_analytics_viewed',
    'merchant_analytics',p_merchant_id::text,
    jsonb_build_object('period_days',p_days,'period_start',v_start_at,'period_end',v_end_at)
  );

  return v_report;
end;
$$;

create or replace function public.merchant_get_advanced_analytics(
  p_merchant_id uuid,
  p_days integer default 30
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.merchant_get_advanced_analytics($1,$2);
$$;

revoke all on function private.merchant_get_advanced_analytics(uuid,integer) from public, anon, authenticated;
revoke all on function public.merchant_get_advanced_analytics(uuid,integer) from public, anon;
grant execute on function private.merchant_get_advanced_analytics(uuid,integer) to authenticated;
grant execute on function public.merchant_get_advanced_analytics(uuid,integer) to authenticated;

update public.subscription_plans
   set live_features = case
         when live_features @> '["advanced_analytics"]'::jsonb then live_features
         else live_features || '["advanced_analytics"]'::jsonb
       end,
       planned_features = planned_features - 'advanced_analytics',
       updated_at = now()
 where plan_key = 'business_39'
   and is_active = true;
