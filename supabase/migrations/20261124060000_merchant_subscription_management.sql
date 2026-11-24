-- WATHAQ merchant plans and subscription administration
-- Applied additively: existing merchants without a subscription remain grandfathered.

create table if not exists public.subscription_plans (
  plan_key text primary key,
  display_name text not null unique,
  price_usd numeric(10,2) not null check (price_usd >= 0),
  billing_interval text not null default 'month' check (billing_interval = 'month'),
  staff_limit integer not null check (staff_limit >= 1),
  active_program_limit integer not null check (active_program_limit >= 1),
  monthly_qr_limit integer not null check (monthly_qr_limit >= 1),
  live_features jsonb not null default '[]'::jsonb check (jsonb_typeof(live_features) = 'array'),
  planned_features jsonb not null default '[]'::jsonb check (jsonb_typeof(planned_features) = 'array'),
  sort_order integer not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.merchant_subscriptions (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null unique references public.merchants(id) on delete cascade,
  plan_key text not null references public.subscription_plans(plan_key) on update cascade on delete restrict,
  status text not null default 'active' check (status in ('active','paused','expired','cancelled')),
  billing_status text not null default 'admin_assigned' check (billing_status in ('admin_assigned','manual_paid','complimentary')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  note text,
  created_by uuid references auth.users(id) on delete set null,
  changed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint merchant_subscriptions_valid_window check (ends_at > starts_at)
);

create index if not exists merchant_subscriptions_plan_status_idx
  on public.merchant_subscriptions(plan_key, status, ends_at);
create index if not exists merchant_subscriptions_ends_at_idx
  on public.merchant_subscriptions(ends_at);

create table if not exists public.subscription_history (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid references public.merchant_subscriptions(id) on delete set null,
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null check (action in ('assigned','upgraded','downgraded','plan_changed','renewed','paused','reactivated','cancelled','payment_marked')),
  from_plan_key text references public.subscription_plans(plan_key) on delete set null,
  to_plan_key text references public.subscription_plans(plan_key) on delete set null,
  from_status text,
  to_status text,
  from_ends_at timestamptz,
  to_ends_at timestamptz,
  billing_status text,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists subscription_history_merchant_created_idx
  on public.subscription_history(merchant_id, created_at desc);

insert into public.subscription_plans
  (plan_key, display_name, price_usd, staff_limit, active_program_limit, monthly_qr_limit, live_features, planned_features, sort_order, is_active)
values
  ('starter_9', 'WATHAQ STARTER', 9, 2, 1, 500,
   '["points_and_stamps","rewards_catalogue","secure_qr_batches","basic_platform_reports"]'::jsonb,
   '[]'::jsonb, 1, true),
  ('growth_19', 'WATHAQ GROWTH', 19, 5, 3, 2500,
   '["points_and_stamps","rewards_catalogue","secure_qr_batches","basic_platform_reports"]'::jsonb,
   '["campaigns","program_branding","csv_export"]'::jsonb, 2, true),
  ('business_39', 'WATHAQ BUSINESS', 39, 15, 10, 10000,
   '["points_and_stamps","rewards_catalogue","secure_qr_batches","basic_platform_reports"]'::jsonb,
   '["advanced_analytics","customer_segments","multi_branch_reports"]'::jsonb, 3, true),
  ('enterprise_99', 'WATHAQ ENTERPRISE', 99, 50, 30, 50000,
   '["points_and_stamps","rewards_catalogue","secure_qr_batches","basic_platform_reports"]'::jsonb,
   '["api_access","custom_roles","multi_branch_management","priority_support","advanced_exports"]'::jsonb, 4, true)
on conflict (plan_key) do update set
  display_name = excluded.display_name,
  price_usd = excluded.price_usd,
  billing_interval = excluded.billing_interval,
  staff_limit = excluded.staff_limit,
  active_program_limit = excluded.active_program_limit,
  monthly_qr_limit = excluded.monthly_qr_limit,
  live_features = excluded.live_features,
  planned_features = excluded.planned_features,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

alter table public.subscription_plans enable row level security;
alter table public.merchant_subscriptions enable row level security;
alter table public.subscription_history enable row level security;
revoke all on public.subscription_plans, public.merchant_subscriptions, public.subscription_history from public, anon, authenticated;

create or replace function private.admin_list_subscription_plans()
returns table (
  plan_key text,
  display_name text,
  price_usd numeric,
  staff_limit integer,
  active_program_limit integer,
  monthly_qr_limit integer,
  live_features jsonb,
  planned_features jsonb,
  sort_order integer,
  is_active boolean
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_platform_admin() then
    raise exception 'only super admin can read subscription plans' using errcode = '42501';
  end if;
  return query
  select p.plan_key, p.display_name, p.price_usd, p.staff_limit,
         p.active_program_limit, p.monthly_qr_limit, p.live_features,
         p.planned_features, p.sort_order, p.is_active
    from public.subscription_plans p
   order by p.sort_order;
end;
$$;

create or replace function public.admin_list_subscription_plans()
returns table (
  plan_key text,
  display_name text,
  price_usd numeric,
  staff_limit integer,
  active_program_limit integer,
  monthly_qr_limit integer,
  live_features jsonb,
  planned_features jsonb,
  sort_order integer,
  is_active boolean
)
language sql
security invoker
set search_path = ''
as $$ select * from private.admin_list_subscription_plans(); $$;

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
         pr.full_name, au.email,
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
      or coalesce(au.email, '') ilike '%' || v_search || '%'
      or m.owner_user_id::text ilike '%' || v_search || '%'
   order by m.created_at desc
   limit v_limit;
end;
$$;

create or replace function public.admin_list_merchant_subscriptions(
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

create or replace function private.admin_create_merchant_account(
  p_owner_user_id uuid,
  p_name text,
  p_slug text,
  p_plan_key text,
  p_duration_months integer default 1,
  p_billing_status text default 'admin_assigned',
  p_category text default null,
  p_description text default null,
  p_country_code text default 'YE',
  p_city text default null,
  p_address text default null,
  p_phone text default null,
  p_email text default null,
  p_timezone text default 'Asia/Aden'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_plan public.subscription_plans%rowtype;
  v_merchant_result jsonb;
  v_merchant_id uuid;
  v_subscription public.merchant_subscriptions%rowtype;
  v_end timestamptz;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_platform_admin() then
    raise exception 'only super admin can create merchant accounts' using errcode = '42501';
  end if;
  if p_duration_months is null or p_duration_months not between 1 and 12 then
    raise exception 'subscription duration must be 1 to 12 months' using errcode = '22023';
  end if;
  if coalesce(p_billing_status, 'admin_assigned') not in ('admin_assigned','manual_paid','complimentary') then
    raise exception 'invalid billing status' using errcode = '22023';
  end if;
  select * into v_plan from public.subscription_plans where plan_key = p_plan_key and is_active = true;
  if not found then
    raise exception 'subscription plan unavailable' using errcode = '22023';
  end if;

  v_merchant_result := private.admin_create_merchant(
    p_owner_user_id, p_name, p_slug, p_category, p_description,
    p_country_code, p_city, p_address, p_phone, p_email, p_timezone
  );
  v_merchant_id := (v_merchant_result->>'merchant_id')::uuid;
  v_end := now() + make_interval(months => p_duration_months);

  insert into public.merchant_subscriptions(
    merchant_id, plan_key, status, billing_status, starts_at, ends_at,
    note, created_by, changed_by
  ) values (
    v_merchant_id, v_plan.plan_key, 'active', p_billing_status, now(), v_end,
    'Initial subscription assigned by platform administrator', v_actor, v_actor
  ) returning * into v_subscription;

  insert into public.subscription_history(
    subscription_id, merchant_id, actor_user_id, action, to_plan_key,
    to_status, to_ends_at, billing_status, note
  ) values (
    v_subscription.id, v_merchant_id, v_actor, 'assigned', v_plan.plan_key,
    v_subscription.status, v_subscription.ends_at, v_subscription.billing_status,
    'Initial subscription assigned during merchant account creation'
  );

  insert into public.audit_events(
    actor_user_id, merchant_id, action, entity_type, entity_id, details
  ) values (
    v_actor, v_merchant_id, 'platform.subscription_assigned',
    'merchant_subscription', v_subscription.id::text,
    jsonb_build_object(
      'plan_key', v_plan.plan_key,
      'price_usd', v_plan.price_usd,
      'duration_months', p_duration_months,
      'billing_status', p_billing_status,
      'ends_at', v_subscription.ends_at
    )
  );

  return jsonb_build_object(
    'ok', true, 'merchant_id', v_merchant_id,
    'subscription_id', v_subscription.id,
    'plan_key', v_plan.plan_key, 'subscription_status', v_subscription.status,
    'starts_at', v_subscription.starts_at, 'ends_at', v_subscription.ends_at,
    'merchant', v_merchant_result
  );
end;
$$;

create or replace function public.admin_create_merchant_account(
  p_owner_user_id uuid,
  p_name text,
  p_slug text,
  p_plan_key text,
  p_duration_months integer default 1,
  p_billing_status text default 'admin_assigned',
  p_category text default null,
  p_description text default null,
  p_country_code text default 'YE',
  p_city text default null,
  p_address text default null,
  p_phone text default null,
  p_email text default null,
  p_timezone text default 'Asia/Aden'
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.admin_create_merchant_account(
    $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14
  );
$$;

create or replace function private.admin_manage_merchant_subscription(
  p_merchant_id uuid,
  p_action text,
  p_plan_key text default null,
  p_duration_months integer default 1,
  p_billing_status text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_sub public.merchant_subscriptions%rowtype;
  v_plan public.subscription_plans%rowtype;
  v_old_plan public.subscription_plans%rowtype;
  v_old_plan_key text;
  v_old_status text;
  v_old_end timestamptz;
  v_action text;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_platform_admin() then
    raise exception 'only super admin can manage subscriptions' using errcode = '42501';
  end if;
  if p_merchant_id is null or p_action not in ('assign','change_plan','renew','pause','reactivate','cancel','mark_paid','mark_comped') then
    raise exception 'invalid subscription action' using errcode = '22023';
  end if;
  if p_note is not null and char_length(p_note) > 500 then
    raise exception 'note must not exceed 500 characters' using errcode = '22023';
  end if;
  if p_action in ('assign','renew') and (p_duration_months is null or p_duration_months not between 1 and 12) then
    raise exception 'duration must be 1 to 12 months' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_merchant_id::text, 0));
  perform 1 from public.merchants where id = p_merchant_id for update;
  if not found then
    raise exception 'merchant not found' using errcode = 'P0002';
  end if;

  select * into v_sub from public.merchant_subscriptions
   where merchant_id = p_merchant_id for update;

  if not found then
    if p_action <> 'assign' then
      raise exception 'merchant has no subscription; assign a plan first' using errcode = 'P0002';
    end if;
    select * into v_plan from public.subscription_plans
     where plan_key = p_plan_key and is_active = true;
    if not found then raise exception 'subscription plan unavailable' using errcode = '22023'; end if;
    if coalesce(p_billing_status, 'admin_assigned') not in ('admin_assigned','manual_paid','complimentary') then
      raise exception 'invalid billing status' using errcode = '22023';
    end if;
    insert into public.merchant_subscriptions(
      merchant_id, plan_key, status, billing_status, starts_at, ends_at,
      note, created_by, changed_by
    ) values (
      p_merchant_id, v_plan.plan_key, 'active',
      coalesce(p_billing_status, 'admin_assigned'), now(),
      now() + make_interval(months => p_duration_months),
      nullif(btrim(p_note), ''), v_actor, v_actor
    ) returning * into v_sub;
    v_action := 'assigned';
    v_old_plan_key := null;
    v_old_status := null;
    v_old_end := null;
  else
    v_old_plan_key := v_sub.plan_key;
    v_old_status := v_sub.status;
    v_old_end := v_sub.ends_at;
    select * into v_old_plan from public.subscription_plans where plan_key = v_sub.plan_key;

    if p_action = 'assign' then
      raise exception 'merchant already has a subscription' using errcode = '23505';
    elsif p_action = 'change_plan' then
      select * into v_plan from public.subscription_plans where plan_key = p_plan_key and is_active = true;
      if not found then raise exception 'subscription plan unavailable' using errcode = '22023'; end if;
      if v_sub.status = 'cancelled' then raise exception 'cancelled subscription cannot change plan' using errcode = '22023'; end if;
      update public.merchant_subscriptions set plan_key=v_plan.plan_key,
        changed_by=v_actor, note=coalesce(nullif(btrim(p_note),''),note), updated_at=now()
       where id=v_sub.id returning * into v_sub;
      v_action := case when v_plan.price_usd > v_old_plan.price_usd then 'upgraded'
                       when v_plan.price_usd < v_old_plan.price_usd then 'downgraded'
                       else 'plan_changed' end;
    elsif p_action = 'renew' then
      if v_sub.status = 'cancelled' then raise exception 'cancelled subscription cannot be renewed' using errcode = '22023'; end if;
      update public.merchant_subscriptions set
        status='active',
        ends_at=greatest(ends_at, now()) + make_interval(months => p_duration_months),
        billing_status=coalesce(p_billing_status,billing_status),
        changed_by=v_actor, note=coalesce(nullif(btrim(p_note),''),note), updated_at=now()
       where id=v_sub.id returning * into v_sub;
      v_action := 'renewed';
    elsif p_action = 'pause' then
      if v_sub.status <> 'active' then raise exception 'only active subscriptions can be paused' using errcode = '22023'; end if;
      update public.merchant_subscriptions set status='paused',changed_by=v_actor,
        note=coalesce(nullif(btrim(p_note),''),note),updated_at=now()
       where id=v_sub.id returning * into v_sub;
      v_action := 'paused';
    elsif p_action = 'reactivate' then
      if v_sub.status <> 'paused' or v_sub.ends_at <= now() then
        raise exception 'only unexpired paused subscriptions can be reactivated; use renew for expired plans' using errcode = '22023';
      end if;
      update public.merchant_subscriptions set status='active',changed_by=v_actor,
        note=coalesce(nullif(btrim(p_note),''),note),updated_at=now()
       where id=v_sub.id returning * into v_sub;
      v_action := 'reactivated';
    elsif p_action = 'cancel' then
      if v_sub.status = 'cancelled' then raise exception 'subscription already cancelled' using errcode = '22023'; end if;
      update public.merchant_subscriptions set status='cancelled',changed_by=v_actor,
        note=coalesce(nullif(btrim(p_note),''),note),updated_at=now()
       where id=v_sub.id returning * into v_sub;
      v_action := 'cancelled';
    elsif p_action in ('mark_paid','mark_comped') then
      update public.merchant_subscriptions set
        billing_status=case when p_action='mark_paid' then 'manual_paid' else 'complimentary' end,
        changed_by=v_actor, note=coalesce(nullif(btrim(p_note),''),note),updated_at=now()
       where id=v_sub.id returning * into v_sub;
      v_action := 'payment_marked';
    end if;
  end if;

  insert into public.subscription_history(
    subscription_id, merchant_id, actor_user_id, action,
    from_plan_key, to_plan_key, from_status, to_status,
    from_ends_at, to_ends_at, billing_status, note
  ) values (
    v_sub.id, p_merchant_id, v_actor, v_action,
    v_old_plan_key, v_sub.plan_key, v_old_status, v_sub.status,
    v_old_end, v_sub.ends_at, v_sub.billing_status,
    nullif(btrim(p_note),'')
  );

  insert into public.audit_events(
    actor_user_id, merchant_id, action, entity_type, entity_id, details
  ) values (
    v_actor, p_merchant_id, 'platform.subscription_' || v_action,
    'merchant_subscription', v_sub.id::text,
    jsonb_build_object(
      'action', v_action, 'from_plan_key', v_old_plan_key,
      'to_plan_key', v_sub.plan_key, 'from_status', v_old_status,
      'to_status', v_sub.status, 'from_ends_at', v_old_end,
      'to_ends_at', v_sub.ends_at, 'billing_status', v_sub.billing_status,
      'note', nullif(btrim(p_note),'')
    )
  );

  return jsonb_build_object(
    'ok', true, 'merchant_id', p_merchant_id,
    'subscription_id', v_sub.id, 'plan_key', v_sub.plan_key,
    'status', v_sub.status, 'billing_status', v_sub.billing_status,
    'starts_at', v_sub.starts_at, 'ends_at', v_sub.ends_at,
    'action', v_action
  );
end;
$$;

create or replace function public.admin_manage_merchant_subscription(
  p_merchant_id uuid,
  p_action text,
  p_plan_key text default null,
  p_duration_months integer default 1,
  p_billing_status text default null,
  p_note text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.admin_manage_merchant_subscription($1,$2,$3,$4,$5,$6);
$$;

-- Platform plan RPCs are admin-only; private functions independently enforce Super Admin.
revoke all on function private.admin_list_subscription_plans() from public, anon, authenticated;
revoke all on function public.admin_list_subscription_plans() from public, anon;
grant execute on function private.admin_list_subscription_plans() to authenticated;
grant execute on function public.admin_list_subscription_plans() to authenticated;

revoke all on function private.admin_list_merchant_subscriptions(text,integer) from public, anon, authenticated;
revoke all on function public.admin_list_merchant_subscriptions(text,integer) from public, anon;
grant execute on function private.admin_list_merchant_subscriptions(text,integer) to authenticated;
grant execute on function public.admin_list_merchant_subscriptions(text,integer) to authenticated;

revoke all on function private.admin_create_merchant_account(uuid,text,text,text,integer,text,text,text,text,text,text,text,text,text) from public, anon, authenticated;
revoke all on function public.admin_create_merchant_account(uuid,text,text,text,integer,text,text,text,text,text,text,text,text,text) from public, anon;
grant execute on function private.admin_create_merchant_account(uuid,text,text,text,integer,text,text,text,text,text,text,text,text,text) to authenticated;
grant execute on function public.admin_create_merchant_account(uuid,text,text,text,integer,text,text,text,text,text,text,text,text,text) to authenticated;

revoke all on function private.admin_manage_merchant_subscription(uuid,text,text,integer,text,text) from public, anon, authenticated;
revoke all on function public.admin_manage_merchant_subscription(uuid,text,text,integer,text,text) from public, anon;
grant execute on function private.admin_manage_merchant_subscription(uuid,text,text,integer,text,text) to authenticated;
grant execute on function public.admin_manage_merchant_subscription(uuid,text,text,integer,text,text) to authenticated;

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
     where mm.merchant_id = new.merchant_id
       and mm.is_active = true
       and mm.user_id <> new.user_id;
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

drop trigger if exists loyalty_program_subscription_capacity on public.loyalty_programs;
create trigger loyalty_program_subscription_capacity
before insert or update on public.loyalty_programs
for each row execute function private.enforce_merchant_subscription_capacity();

drop trigger if exists merchant_member_subscription_capacity on public.merchant_members;
create trigger merchant_member_subscription_capacity
before insert or update of is_active on public.merchant_members
for each row execute function private.enforce_merchant_subscription_capacity();

drop trigger if exists qr_batch_subscription_capacity on private.wathaq_qr_batches;
create trigger qr_batch_subscription_capacity
before insert on private.wathaq_qr_batches
for each row execute function private.enforce_merchant_subscription_capacity();

revoke all on function private.enforce_merchant_subscription_capacity() from public, anon, authenticated;
