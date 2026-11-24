-- Harden subscription enforcement at the database boundary.
-- Missing subscriptions must not silently bypass merchant quotas.
-- Active plan changes are rejected when existing usage exceeds the target plan.

create or replace function private.enforce_merchant_subscription_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_sub public.merchant_subscriptions%rowtype;
  v_plan public.subscription_plans%rowtype;
  v_used bigint;
  v_period_start timestamptz;
begin
  if tg_table_schema = 'public' and tg_table_name = 'loyalty_programs' then
    if new.state::text <> 'active' then return new; end if;
    if tg_op = 'UPDATE'
       and old.state::text = 'active'
       and old.merchant_id = new.merchant_id then
      return new;
    end if;
  elsif tg_table_schema = 'public' and tg_table_name = 'merchant_members' then
    if not new.is_active then return new; end if;
    if tg_op = 'UPDATE'
       and old.is_active
       and old.merchant_id = new.merchant_id
       and old.user_id = new.user_id then
      return new;
    end if;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.merchant_id::text, 0)
  );

  select * into v_sub
    from public.merchant_subscriptions
   where merchant_id = new.merchant_id;

  if not found then
    raise exception 'an active merchant subscription is required'
      using errcode = 'P0001';
  end if;

  if v_sub.status <> 'active'
     or v_sub.starts_at > now()
     or v_sub.ends_at <= now() then
    raise exception 'merchant subscription is not active'
      using errcode = 'P0001';
  end if;

  select * into v_plan
    from public.subscription_plans
   where plan_key = v_sub.plan_key
     and is_active = true;

  if not found then
    raise exception 'merchant subscription plan is unavailable'
      using errcode = 'P0001';
  end if;

  if tg_table_schema = 'public' and tg_table_name = 'loyalty_programs' then
    if new.state::text <> 'active' then return new; end if;
    select count(*) into v_used
      from public.loyalty_programs p
     where p.merchant_id = new.merchant_id
       and p.state::text = 'active'
       and (tg_op <> 'UPDATE' or p.id <> new.id);
    if v_used >= v_plan.active_program_limit then
      raise exception 'active loyalty program limit reached for this subscription'
        using errcode = 'P0001';
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
      raise exception 'active merchant staff limit reached for this subscription'
        using errcode = 'P0001';
    end if;
  elsif tg_table_schema = 'private' and tg_table_name = 'wathaq_qr_batches' then
    v_period_start := pg_catalog.date_trunc('month', now() at time zone 'UTC') at time zone 'UTC';
    select coalesce(sum(b.quantity),0)::bigint into v_used
      from private.wathaq_qr_batches b
     where b.merchant_id = new.merchant_id
       and b.created_at >= v_period_start;
    if v_used + new.quantity > v_plan.monthly_qr_limit then
      raise exception 'monthly QR code limit reached for this subscription'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$function$;

create or replace function private.enforce_subscription_plan_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_plan public.subscription_plans%rowtype;
  v_programs bigint;
  v_staff bigint;
  v_qr bigint;
  v_period_start timestamptz;
begin
  if new.status <> 'active' then
    return new;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.merchant_id::text, 0)
  );

  select * into v_plan
    from public.subscription_plans
   where plan_key = new.plan_key
     and is_active = true;

  if not found then
    raise exception 'subscription plan is unavailable'
      using errcode = 'P0001';
  end if;

  select count(*) into v_programs
    from public.loyalty_programs p
   where p.merchant_id = new.merchant_id
     and p.state::text = 'active';

  if v_programs > v_plan.active_program_limit then
    raise exception 'existing active loyalty programs exceed the selected plan limit'
      using errcode = 'P0001';
  end if;

  select count(*) into v_staff
    from public.merchant_members mm
    join public.merchants m on m.id = mm.merchant_id
   where mm.merchant_id = new.merchant_id
     and mm.is_active = true
     and mm.user_id <> m.owner_user_id;

  if v_staff > v_plan.staff_limit then
    raise exception 'existing active merchant staff exceed the selected plan limit'
      using errcode = 'P0001';
  end if;

  v_period_start := pg_catalog.date_trunc('month', now() at time zone 'UTC') at time zone 'UTC';
  select coalesce(sum(b.quantity),0)::bigint into v_qr
    from private.wathaq_qr_batches b
   where b.merchant_id = new.merchant_id
     and b.created_at >= v_period_start;

  if v_qr > v_plan.monthly_qr_limit then
    raise exception 'QR codes already issued this month exceed the selected plan limit'
      using errcode = 'P0001';
  end if;

  return new;
end;
$function$;

revoke all on function private.enforce_subscription_plan_capacity() from public, anon, authenticated;

-- The existing trigger must also fire if an active staff row is reassigned.
drop trigger if exists merchant_member_subscription_capacity on public.merchant_members;
create trigger merchant_member_subscription_capacity
before insert or update of is_active, merchant_id, user_id
on public.merchant_members
for each row
execute function private.enforce_merchant_subscription_capacity();

drop trigger if exists merchant_subscription_plan_capacity on public.merchant_subscriptions;
create trigger merchant_subscription_plan_capacity
before insert or update of plan_key, status
on public.merchant_subscriptions
for each row
execute function private.enforce_subscription_plan_capacity();

-- Higher tiers inherit all currently-live features from lower tiers.
-- Planned features remain planned and are not silently activated.
update public.subscription_plans p
   set live_features = (
     select jsonb_agg(to_jsonb(f.feature) order by f.ord)
       from (
         select e.value as feature, e.ordinality as ord
           from jsonb_array_elements_text(p.live_features) with ordinality as e(value, ordinality)
         union all
         select x.feature, x.ord
           from (values
             ('csv_export', 100),
             ('advanced_analytics', 101),
             ('customer_segments', 102)
           ) as x(feature, ord)
          where not (p.live_features @> jsonb_build_array(x.feature))
       ) f
   ),
   planned_features = planned_features - 'csv_export' - 'advanced_analytics' - 'customer_segments',
   updated_at = now()
 where p.plan_key = 'business_39'
   and p.is_active = true;

update public.subscription_plans p
   set live_features = (
     select jsonb_agg(to_jsonb(f.feature) order by f.ord)
       from (
         select e.value as feature, e.ordinality as ord
           from jsonb_array_elements_text(p.live_features) with ordinality as e(value, ordinality)
         union all
         select x.feature, x.ord
           from (values
             ('csv_export', 100),
             ('advanced_analytics', 101),
             ('customer_segments', 102)
           ) as x(feature, ord)
          where not (p.live_features @> jsonb_build_array(x.feature))
       ) f
   ),
   planned_features = planned_features - 'csv_export' - 'advanced_analytics' - 'customer_segments',
   updated_at = now()
 where p.plan_key = 'enterprise_99'
   and p.is_active = true;
