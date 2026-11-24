-- Merchant owner workspace and a real, audited Growth-plan CSV export.
-- Exported customer identifiers are opaque UUID references; no name, email, or phone is returned.

create or replace function private.merchant_get_my_workspace()
returns table (
  merchant_id uuid,
  merchant_name text,
  merchant_slug text,
  merchant_status text,
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
  planned_features jsonb,
  loyalty_programs_total bigint,
  active_programs_total bigint,
  loyalty_accounts_total bigint,
  rewards_total bigint,
  active_rewards_total bigint,
  points_earned_30d bigint,
  points_redeemed_30d bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  return query
  select
    m.id,
    m.name,
    m.slug,
    m.status::text,
    s.plan_key,
    p.display_name,
    p.price_usd,
    case
      when s.id is null then 'unassigned'
      when s.status = 'active' and (s.starts_at > now() or s.ends_at <= now()) then 'expired'
      else s.status
    end,
    s.billing_status,
    s.starts_at,
    s.ends_at,
    p.staff_limit,
    p.active_program_limit,
    p.monthly_qr_limit,
    coalesce(p.live_features, '[]'::jsonb),
    coalesce(p.planned_features, '[]'::jsonb),
    (select count(*)::bigint from public.loyalty_programs lp where lp.merchant_id = m.id),
    (select count(*)::bigint from public.loyalty_programs lp where lp.merchant_id = m.id and lp.state::text = 'active'),
    (select count(*)::bigint from public.loyalty_accounts la where la.merchant_id = m.id),
    (select count(*)::bigint from public.rewards rw where rw.merchant_id = m.id),
    (select count(*)::bigint from public.rewards rw where rw.merchant_id = m.id and rw.is_active = true),
    coalesce((
      select sum(ll.points_delta)
        from public.loyalty_ledger ll
       where ll.merchant_id = m.id
         and ll.kind = 'earn'
         and ll.created_at >= now() - interval '30 days'
    ), 0)::bigint,
    coalesce((
      select sum(-ll.points_delta)
        from public.loyalty_ledger ll
       where ll.merchant_id = m.id
         and ll.kind = 'redeem'
         and ll.created_at >= now() - interval '30 days'
    ), 0)::bigint
  from public.merchants m
  left join public.merchant_subscriptions s on s.merchant_id = m.id
  left join public.subscription_plans p on p.plan_key = s.plan_key
  where m.owner_user_id = v_actor
  order by m.created_at desc;
end;
$$;

create or replace function public.merchant_get_my_workspace()
returns table (
  merchant_id uuid,
  merchant_name text,
  merchant_slug text,
  merchant_status text,
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
  planned_features jsonb,
  loyalty_programs_total bigint,
  active_programs_total bigint,
  loyalty_accounts_total bigint,
  rewards_total bigint,
  active_rewards_total bigint,
  points_earned_30d bigint,
  points_redeemed_30d bigint
)
language sql
security invoker
set search_path = ''
as $$
  select * from private.merchant_get_my_workspace();
$$;

create or replace function private.merchant_export_loyalty_accounts(
  p_merchant_id uuid,
  p_after_joined_at timestamptz default null,
  p_after_account_id uuid default null,
  p_snapshot_at timestamptz default null,
  p_limit integer default 1000
)
returns table (
  account_id uuid,
  customer_reference uuid,
  program_name text,
  program_kind text,
  points_balance bigint,
  stamps_balance integer,
  lifetime_points bigint,
  lifetime_stamps bigint,
  joined_at timestamptz,
  last_activity_at timestamptz,
  snapshot_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_merchant_status text;
  v_subscription_status text;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_live_features jsonb;
  v_snapshot_at timestamptz;
  v_rows bigint;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_merchant_id is null then
    raise exception 'merchant is required' using errcode = '22023';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 1000 then
    raise exception 'page size must be between 1 and 1000' using errcode = '22023';
  end if;
  if (p_after_joined_at is null) <> (p_after_account_id is null) then
    raise exception 'both export cursor values must be supplied together' using errcode = '22023';
  end if;

  v_snapshot_at := coalesce(p_snapshot_at, statement_timestamp());
  if v_snapshot_at > statement_timestamp()
     or v_snapshot_at < statement_timestamp() - interval '24 hours' then
    raise exception 'export snapshot is outside the permitted window' using errcode = '22023';
  end if;

  select m.status::text, s.status, s.starts_at, s.ends_at, p.live_features
    into v_merchant_status, v_subscription_status, v_starts_at, v_ends_at, v_live_features
    from public.merchants m
    join public.merchant_subscriptions s on s.merchant_id = m.id
    join public.subscription_plans p on p.plan_key = s.plan_key
   where m.id = p_merchant_id
     and m.owner_user_id = v_actor;

  if not found then
    raise exception 'merchant not found or access denied' using errcode = '42501';
  end if;
  if v_merchant_status <> 'active' then
    raise exception 'merchant must be active before exporting customer data' using errcode = '42501';
  end if;
  if v_subscription_status <> 'active'
     or v_starts_at > now()
     or v_ends_at <= now() then
    raise exception 'an active, current subscription is required' using errcode = '42501';
  end if;
  if not (coalesce(v_live_features, '[]'::jsonb) @> '["csv_export"]'::jsonb) then
    raise exception 'CSV export is not included in the current subscription plan' using errcode = '42501';
  end if;

  return query
  select
    a.id,
    a.customer_id,
    lp.name,
    lp.kind::text,
    a.points_balance,
    a.stamps_balance,
    a.lifetime_points,
    a.lifetime_stamps,
    a.joined_at,
    a.last_activity_at,
    v_snapshot_at
  from public.loyalty_accounts a
  join public.loyalty_programs lp
    on lp.id = a.program_id
   and lp.merchant_id = a.merchant_id
  where a.merchant_id = p_merchant_id
    and a.joined_at <= v_snapshot_at
    and (
      p_after_joined_at is null
      or (a.joined_at, a.id) > (p_after_joined_at, p_after_account_id)
    )
  order by a.joined_at, a.id
  limit p_limit;

  get diagnostics v_rows = row_count;
  if v_rows > 0 then
    insert into public.audit_events (
      actor_user_id, merchant_id, action, entity_type, entity_id, details
    ) values (
      v_actor,
      p_merchant_id,
      'merchant.loyalty_accounts_csv_exported',
      'loyalty_account_export',
      p_merchant_id::text,
      jsonb_build_object(
        'records_returned', v_rows,
        'page_size', p_limit,
        'snapshot_at', v_snapshot_at,
        'cursor_used', p_after_account_id is not null
      )
    );
  end if;
end;
$$;

create or replace function public.merchant_export_loyalty_accounts(
  p_merchant_id uuid,
  p_after_joined_at timestamptz default null,
  p_after_account_id uuid default null,
  p_snapshot_at timestamptz default null,
  p_limit integer default 1000
)
returns table (
  account_id uuid,
  customer_reference uuid,
  program_name text,
  program_kind text,
  points_balance bigint,
  stamps_balance integer,
  lifetime_points bigint,
  lifetime_stamps bigint,
  joined_at timestamptz,
  last_activity_at timestamptz,
  snapshot_at timestamptz
)
language sql
security invoker
set search_path = ''
as $$
  select * from private.merchant_export_loyalty_accounts($1, $2, $3, $4, $5);
$$;

revoke all on function private.merchant_get_my_workspace() from public, anon, authenticated;
revoke all on function public.merchant_get_my_workspace() from public, anon;
grant execute on function private.merchant_get_my_workspace() to authenticated;
grant execute on function public.merchant_get_my_workspace() to authenticated;

revoke all on function private.merchant_export_loyalty_accounts(uuid, timestamptz, uuid, timestamptz, integer) from public, anon, authenticated;
revoke all on function public.merchant_export_loyalty_accounts(uuid, timestamptz, uuid, timestamptz, integer) from public, anon;
grant execute on function private.merchant_export_loyalty_accounts(uuid, timestamptz, uuid, timestamptz, integer) to authenticated;
grant execute on function public.merchant_export_loyalty_accounts(uuid, timestamptz, uuid, timestamptz, integer) to authenticated;

update public.subscription_plans
   set live_features = case
         when live_features @> '["csv_export"]'::jsonb then live_features
         else live_features || '["csv_export"]'::jsonb
       end,
       planned_features = planned_features - 'csv_export',
       updated_at = now()
 where plan_key = 'growth_19'
   and is_active = true;
