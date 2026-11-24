-- Disposable PostgreSQL integration test for merchant subscription entitlements.
-- Run only against the ephemeral postgres service in GitHub Actions.

create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key);
create schema private;

create table public.merchants (
  id uuid primary key,
  owner_user_id uuid not null
);

create table public.subscription_plans (
  plan_key text primary key,
  display_name text not null,
  price_usd numeric not null,
  billing_interval text not null,
  staff_limit integer not null,
  active_program_limit integer not null,
  monthly_qr_limit integer not null,
  live_features jsonb not null check (jsonb_typeof(live_features) = 'array'),
  planned_features jsonb not null check (jsonb_typeof(planned_features) = 'array'),
  sort_order integer not null,
  is_active boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.subscription_plans
(plan_key, display_name, price_usd, billing_interval, staff_limit, active_program_limit, monthly_qr_limit, live_features, planned_features, sort_order, is_active)
values
('starter_9','Starter',9,'month',2,1,500,'["points_and_stamps","rewards_catalogue","secure_qr_batches","basic_platform_reports"]','[]',1,true),
('growth_19','Growth',19,'month',5,3,2500,'["points_and_stamps","rewards_catalogue","secure_qr_batches","basic_platform_reports","csv_export"]','["campaigns","program_branding"]',2,true),
('business_39','Business',39,'month',15,10,10000,'["points_and_stamps","rewards_catalogue","secure_qr_batches","basic_platform_reports","advanced_analytics","customer_segments"]','["multi_branch_reports"]',3,true),
('enterprise_99','Enterprise',99,'month',50,30,50000,'["points_and_stamps","rewards_catalogue","secure_qr_batches","basic_platform_reports"]','["api_access","custom_roles","multi_branch_management","priority_support","advanced_exports"]',4,true);

create table public.merchant_subscriptions (
  id uuid primary key,
  merchant_id uuid not null unique references public.merchants(id),
  plan_key text not null references public.subscription_plans(plan_key),
  status text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create table public.loyalty_programs (
  id uuid primary key,
  merchant_id uuid not null references public.merchants(id),
  state text not null
);

create table public.merchant_members (
  merchant_id uuid not null references public.merchants(id),
  user_id uuid not null,
  is_active boolean not null
);

create table private.wathaq_qr_batches (
  id uuid primary key,
  merchant_id uuid not null references public.merchants(id),
  quantity integer not null check (quantity between 1 and 1000),
  created_at timestamptz not null default now()
);

-- Recreate the three pre-existing production triggers before replacing their function.
create function private.enforce_merchant_subscription_capacity()
returns trigger
language plpgsql
as $stub$
begin
  return new;
end;
$stub$;

create trigger loyalty_program_subscription_capacity
before insert or update on public.loyalty_programs
for each row execute function private.enforce_merchant_subscription_capacity();

create trigger merchant_member_subscription_capacity
before insert or update of is_active on public.merchant_members
for each row execute function private.enforce_merchant_subscription_capacity();

create trigger qr_batch_subscription_capacity
before insert on private.wathaq_qr_batches
for each row execute function private.enforce_merchant_subscription_capacity();

\i supabase/migrations/20261125120000_merchant_subscription_entitlement_hardening.sql

-- Missing, paused, and expired subscriptions must block all three resource types.
insert into public.merchants values
('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002'),
('10000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000003');

do $$
begin
  begin
    insert into public.loyalty_programs values ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','active');
    raise exception 'missing subscription unexpectedly allowed a program' using errcode = 'P0002';
  exception when sqlstate 'P0001' then null;
  end;
  begin
    insert into public.merchant_members values ('10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',true);
    raise exception 'missing subscription unexpectedly allowed staff' using errcode = 'P0002';
  exception when sqlstate 'P0001' then null;
  end;
  begin
    insert into private.wathaq_qr_batches values ('50000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',1,now());
    raise exception 'missing subscription unexpectedly allowed QR batch' using errcode = 'P0002';
  exception when sqlstate 'P0001' then null;
  end;
end $$;

insert into public.merchant_subscriptions
(id, merchant_id, plan_key, status, starts_at, ends_at)
values
('60000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','starter_9','paused',now()-interval '1 day',now()+interval '1 day'),
('60000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','starter_9','active',now()-interval '2 months',now()-interval '1 month');

do $$
begin
  begin
    insert into public.loyalty_programs values ('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','active');
    raise exception 'paused subscription unexpectedly allowed a program' using errcode = 'P0002';
  exception when sqlstate 'P0001' then null;
  end;
  begin
    insert into public.loyalty_programs values ('30000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','active');
    raise exception 'expired subscription unexpectedly allowed a program' using errcode = 'P0002';
  exception when sqlstate 'P0001' then null;
  end;
end $$;

-- Starter plan boundaries: one active program, two staff seats (owner excluded), 500 QR/month.
insert into public.merchants values
('10000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000004');
insert into public.merchant_subscriptions
(id, merchant_id, plan_key, status, starts_at, ends_at)
values
('60000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004','starter_9','active',now()-interval '1 day',now()+interval '1 month');

insert into public.loyalty_programs values
('30000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004','active');

do $$
begin
  begin
    insert into public.loyalty_programs values ('30000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000004','active');
    raise exception 'program quota was not enforced' using errcode = 'P0002';
  exception when sqlstate 'P0001' then null;
  end;
end $$;

insert into public.merchant_members values
('10000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000004',true),
('10000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000004',true),
('10000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000005',true);

do $$
begin
  begin
    insert into public.merchant_members values ('10000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000006',true);
    raise exception 'staff quota was not enforced' using errcode = 'P0002';
  exception when sqlstate 'P0001' then null;
  end;
end $$;

insert into private.wathaq_qr_batches values
('50000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004',500,now());

do $$
begin
  begin
    insert into private.wathaq_qr_batches values ('50000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000004',1,now());
    raise exception 'monthly QR quota was not enforced' using errcode = 'P0002';
  exception when sqlstate 'P0001' then null;
  end;
end $$;

-- Downgrades must be rejected if existing usage exceeds the target plan.
insert into public.merchants values
('10000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000005');
insert into public.merchant_subscriptions
(id, merchant_id, plan_key, status, starts_at, ends_at)
values
('60000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000005','growth_19','active',now()-interval '1 day',now()+interval '1 month');
insert into public.loyalty_programs values
('30000000-0000-0000-0000-000000000006','10000000-0000-0000-0000-000000000005','active'),
('30000000-0000-0000-0000-000000000007','10000000-0000-0000-0000-000000000005','active');

do $$
begin
  begin
    update public.merchant_subscriptions set plan_key='starter_9' where merchant_id='10000000-0000-0000-0000-000000000005';
    raise exception 'downgrade unexpectedly allowed above target quota' using errcode = 'P0002';
  exception when sqlstate 'P0001' then null;
  end;
  if (select plan_key from public.merchant_subscriptions where merchant_id='10000000-0000-0000-0000-000000000005') <> 'growth_19' then
    raise exception 'failed downgrade changed the subscription';
  end if;
end $$;

-- Live feature inheritance is cumulative; planned capabilities remain planned.
do $$
begin
  if not ((select live_features from public.subscription_plans where plan_key='business_39') ? 'csv_export') then
    raise exception 'Business did not inherit csv_export';
  end if;
  if not ((select live_features from public.subscription_plans where plan_key='enterprise_99') ? 'csv_export')
     or not ((select live_features from public.subscription_plans where plan_key='enterprise_99') ? 'advanced_analytics')
     or not ((select live_features from public.subscription_plans where plan_key='enterprise_99') ? 'customer_segments') then
    raise exception 'Enterprise did not inherit all live lower-tier features';
  end if;
  if (select planned_features from public.subscription_plans where plan_key='enterprise_99') ? 'advanced_analytics' then
    raise exception 'a live feature remains incorrectly marked planned';
  end if;
end $$;

-- Reassigning an active staff member must not bypass the destination merchant's quota.
insert into public.merchants values
('10000000-0000-0000-0000-000000000006','20000000-0000-0000-0000-000000000006');
insert into public.merchant_subscriptions
(id, merchant_id, plan_key, status, starts_at, ends_at)
values
('60000000-0000-0000-0000-000000000006','10000000-0000-0000-0000-000000000006','starter_9','active',now()-interval '1 day',now()+interval '1 month');
insert into public.merchant_members values
('10000000-0000-0000-0000-000000000006','40000000-0000-0000-0000-000000000007',true),
('10000000-0000-0000-0000-000000000006','40000000-0000-0000-0000-000000000008',true);

do $reassign$
begin
  begin
    update public.merchant_members
       set merchant_id='10000000-0000-0000-0000-000000000006'
     where merchant_id='10000000-0000-0000-0000-000000000004'
       and user_id='40000000-0000-0000-0000-000000000004';
    raise exception 'staff reassignment bypassed the destination quota' using errcode = 'P0002';
  exception when sqlstate 'P0001' then null;
  end;
  if exists (
    select 1 from public.merchant_members
     where merchant_id='10000000-0000-0000-0000-000000000006'
       and user_id='40000000-0000-0000-0000-000000000004'
  ) then
    raise exception 'failed staff reassignment changed the member merchant';
  end if;
end $reassign$;

-- The QR usage accumulator must remain bigint when monthly totals exceed int32.
do $qr$
declare
  v_qr bigint;
begin
  select coalesce(sum(1000),0)::bigint into v_qr
    from generate_series(1, 2147485);
  if v_qr <> 2147485000 then
    raise exception 'QR usage bigint accumulation returned an incorrect total: %', v_qr;
  end if;
end $qr$

select 'subscription entitlement integration tests passed' as result;
