-- WATHAQ: subscription staff seats count employees, not the merchant owner.
-- The owner membership is created automatically and must not consume a paid staff seat.

create or replace function private.enforce_merchant_subscription_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sub public.merchant_subscriptions%rowtype;
  v_plan public.subscription_plans%rowtype;
  v_used integer;
  v_period_start timestamptz;
begin
  -- Resource-decreasing or metadata-only changes do not consume new plan capacity.
  if tg_table_schema = 'public' and tg_table_name = 'loyalty_programs' then
    if new.state::text <> 'active' then return new; end if;
    if tg_op = 'UPDATE' and old.state::text = 'active' then return new; end if;
  elsif tg_table_schema = 'public' and tg_table_name = 'merchant_members' then
    if not new.is_active then return new; end if;
    if tg_op = 'UPDATE' and old.is_active then return new; end if;
  end if;

  -- Serialize per merchant so concurrent resource creation cannot exceed a plan limit.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.merchant_id::text, 0));

  select * into v_sub from public.merchant_subscriptions
   where merchant_id = new.merchant_id;
  if not found then
    -- Existing merchants without a subscription are grandfathered.
    return new;
  end if;

  if v_sub.status <> 'active' or v_sub.starts_at > now() or v_sub.ends_at <= now() then
    raise exception 'merchant subscription is not active' using errcode = 'P0001';
  end if;

  select * into v_plan from public.subscription_plans
   where plan_key = v_sub.plan_key and is_active = true;
  if not found then
    raise exception 'merchant subscription plan is unavailable' using errcode = 'P0001';
  end if;

  if tg_table_schema = 'public' and tg_table_name = 'loyalty_programs' then
    if new.state::text <> 'active' then return new; end if;
    select count(*) into v_used
      from public.loyalty_programs p
     where p.merchant_id = new.merchant_id
       and p.state::text = 'active'
       and (tg_op <> 'UPDATE' or p.id <> new.id);
    if v_used >= v_plan.active_program_limit then
      raise exception 'active loyalty program limit reached for this subscription' using errcode = 'P0001';
    end if;
  elsif tg_table_schema = 'public' and tg_table_name = 'merchant_members' then
    if not new.is_active then return new; end if;
    select count(*) into v_used
      from public.merchant_members mm
      join public.merchants m on m.id = mm.merchant_id
     where mm.merchant_id = new.merchant_id
       and mm.is_active = true
       and mm.user_id <> new.user_id
       and mm.user_id <> m.owner_user_id;
    if v_used >= v_plan.staff_limit then
      raise exception 'active merchant staff limit reached for this subscription' using errcode = 'P0001';
    end if;
  elsif tg_table_schema = 'private' and tg_table_name = 'wathaq_qr_batches' then
    v_period_start := pg_catalog.date_trunc('month', now() at time zone 'UTC') at time zone 'UTC';
    select coalesce(sum(b.quantity),0)::integer into v_used
      from private.wathaq_qr_batches b
     where b.merchant_id = new.merchant_id
       and b.created_at >= v_period_start;
    if v_used + new.quantity > v_plan.monthly_qr_limit then
      raise exception 'monthly QR code limit reached for this subscription' using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_merchant_subscription_capacity() from public, anon, authenticated;
