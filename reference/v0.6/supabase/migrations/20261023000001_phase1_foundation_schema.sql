-- WATHAQ Phase 1 foundation (applied to wathaq-dev). Server is source of truth; clients never write balances.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create type public.merchant_status as enum ('pending','approved','suspended');
create type public.program_type as enum ('stamps','points');
create type public.program_status as enum ('draft','active','paused');
create type public.subscription_status as enum ('trial','active','grace','suspended','expired');
create type public.tx_type as enum ('earn','redeem','adjust','void');
create type public.token_kind as enum ('earn','redeem');
create type public.token_status as enum ('active','used','expired','cancelled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  locale text not null default 'ar' check (locale in ('ar','en')),
  deletion_requested_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table public.platform_settings (
  key text primary key, value jsonb not null, updated_at timestamptz not null default now()
);
create table public.plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique, name_ar text not null,
  price_usd numeric(8,2) not null check (price_usd >= 0),
  features jsonb not null default '[]'::jsonb,
  is_active boolean not null default false, sort_order int not null default 0
);
create table public.tiers (
  code text primary key, name_ar text not null,
  min_earns_12m int not null check (min_earns_12m >= 0), sort_order int not null
);
create table public.merchants (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  name text not null check (char_length(name) between 2 and 120),
  category text, description text, city text, area text,
  status public.merchant_status not null default 'pending',
  is_test boolean not null default false,
  created_at timestamptz not null default now()
);
create index merchants_owner_idx on public.merchants(owner_id);
create index merchants_status_idx on public.merchants(status);
create table public.merchant_staff (
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  permissions text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (merchant_id, user_id)
);
create index merchant_staff_user_idx on public.merchant_staff(user_id);
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id),
  plan_id uuid references public.plans(id),
  status public.subscription_status not null default 'trial',
  started_at timestamptz not null default now(), ends_at timestamptz,
  grace_days int not null default 3 check (grace_days >= 0),
  created_at timestamptz not null default now()
);
create index subscriptions_merchant_idx on public.subscriptions(merchant_id);
create table public.subscription_events (
  id bigint generated always as identity primary key,
  subscription_id uuid not null references public.subscriptions(id),
  actor_id uuid, event text not null, details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.programs (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  type public.program_type not null, name text not null,
  rules jsonb not null default '{}'::jsonb, version int not null default 1,
  status public.program_status not null default 'draft',
  created_at timestamptz not null default now()
);
create index programs_merchant_idx on public.programs(merchant_id);
create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.programs(id) on delete cascade,
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  title text not null, cost int not null check (cost > 0),
  is_active boolean not null default true, created_at timestamptz not null default now()
);
create index rewards_program_idx on public.rewards(program_id);
create table public.cards (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id),
  program_id uuid not null references public.programs(id),
  merchant_id uuid not null references public.merchants(id),
  stamps int not null default 0 check (stamps >= 0),
  points int not null default 0 check (points >= 0),
  created_at timestamptz not null default now(),
  unique (customer_id, program_id)
);
create index cards_merchant_idx on public.cards(merchant_id);
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references public.cards(id),
  customer_id uuid not null, merchant_id uuid not null, program_id uuid not null,
  type public.tx_type not null, amount int not null, reason text, program_version int,
  idempotency_key text not null unique, created_by uuid,
  created_at timestamptz not null default now()
);
create index tx_customer_idx on public.transactions(customer_id, created_at desc);
create index tx_merchant_idx on public.transactions(merchant_id, created_at desc);
create table public.reward_tokens (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id),
  program_id uuid references public.programs(id),
  kind public.token_kind not null, token_hash text not null unique,
  customer_id uuid references auth.users(id),
  status public.token_status not null default 'active',
  expires_at timestamptz not null, used_at timestamptz,
  created_by uuid not null, created_at timestamptz not null default now()
);
create table public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, merchant_id)
);
create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid, action text not null, entity text not null, entity_id text,
  details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.platform_admins where user_id = (select auth.uid()));
$$;
create function private.is_merchant_owner(mid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.merchants where id = mid and owner_id = (select auth.uid()));
$$;
create function private.is_merchant_member(mid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.is_merchant_owner(mid) or exists (
    select 1 from public.merchant_staff
    where merchant_id = mid and user_id = (select auth.uid()) and is_active);
$$;
create function private.phone_verified() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from auth.users where id = (select auth.uid()) and phone_confirmed_at is not null);
$$;
grant execute on function private.is_admin(), private.is_merchant_owner(uuid),
  private.is_merchant_member(uuid), private.phone_verified() to authenticated;

create function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin insert into public.profiles (id) values (new.id) on conflict do nothing; return new; end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

create function private.block_mutation() returns trigger
language plpgsql set search_path = '' as $$
begin raise exception 'immutable table: % not allowed on %', tg_op, tg_table_name using errcode = '42501'; end $$;
create trigger audit_logs_immutable before update or delete on public.audit_logs
  for each row execute function private.block_mutation();
create trigger transactions_immutable before update or delete on public.transactions
  for each row execute function private.block_mutation();
create trigger subscription_events_immutable before update or delete on public.subscription_events
  for each row execute function private.block_mutation();

create function private.program_rules_versioning() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.rules is distinct from old.rules or new.type is distinct from old.type then
    new.version := old.version + 1;
    insert into public.audit_logs(actor_id, action, entity, entity_id, details)
    values ((select auth.uid()), 'program.rules_changed', 'program', old.id::text,
            jsonb_build_object('old_version', old.version, 'new_version', new.version));
  end if;
  return new;
end $$;
create trigger programs_versioning before update on public.programs
  for each row execute function private.program_rules_versioning();

create function public.my_tier() returns text
language sql stable set search_path = '' as $$
  select t.code from public.tiers t
  where t.min_earns_12m <= (
    select count(*) from public.transactions x
    where x.customer_id = (select auth.uid()) and x.type = 'earn'
      and x.created_at > now() - interval '12 months')
  order by t.min_earns_12m desc limit 1;
$$;
revoke execute on function public.my_tier() from public, anon;
grant execute on function public.my_tier() to authenticated;

create function public.join_program(p_program_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_merchant uuid; v_card uuid;
begin
  if (select auth.uid()) is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select p.merchant_id into v_merchant
  from public.programs p join public.merchants m on m.id = p.merchant_id
  where p.id = p_program_id and p.status = 'active' and m.status = 'approved';
  if v_merchant is null then raise exception 'program unavailable' using errcode='P0002'; end if;
  insert into public.cards(customer_id, program_id, merchant_id)
  values ((select auth.uid()), p_program_id, v_merchant)
  on conflict (customer_id, program_id) do nothing;
  select id into v_card from public.cards
  where customer_id = (select auth.uid()) and program_id = p_program_id;
  return v_card;
end $$;
revoke execute on function public.join_program(uuid) from public, anon;
grant execute on function public.join_program(uuid) to authenticated;

revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from anon;
grant select on public.profiles, public.plans, public.tiers, public.platform_settings,
  public.merchants, public.merchant_staff, public.subscriptions, public.programs,
  public.rewards, public.cards, public.transactions, public.favorites,
  public.audit_logs, public.platform_admins, public.subscription_events to authenticated;
grant update (display_name, locale, deletion_requested_at) on public.profiles to authenticated;
grant insert (owner_id, name, category, description, city, area) on public.merchants to authenticated;
grant update (name, category, description, city, area) on public.merchants to authenticated;
grant insert, update, delete on public.merchant_staff to authenticated;
grant insert (merchant_id, type, name, rules, status) on public.programs to authenticated;
grant update (name, rules, status) on public.programs to authenticated;
grant insert (program_id, merchant_id, title, cost, is_active) on public.rewards to authenticated;
grant update (title, cost, is_active) on public.rewards to authenticated;
grant insert, delete on public.favorites to authenticated;
grant insert, update, delete on public.plans, public.tiers, public.platform_settings to authenticated;
grant update (status) on public.merchants to authenticated;
grant insert, update on public.subscriptions to authenticated;

create function private.guard_merchant_status() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status is distinct from old.status and not private.is_admin() then
    raise exception 'only platform admins may change merchant status' using errcode='42501';
  end if;
  if new.status is distinct from old.status then
    insert into public.audit_logs(actor_id, action, entity, entity_id, details)
    values ((select auth.uid()), 'merchant.status_changed', 'merchant', old.id::text,
            jsonb_build_object('from', old.status, 'to', new.status));
  end if;
  return new;
end $$;
create trigger merchants_status_guard before update on public.merchants
  for each row execute function private.guard_merchant_status();

alter table public.profiles enable row level security;
alter table public.platform_admins enable row level security;
alter table public.platform_settings enable row level security;
alter table public.plans enable row level security;
alter table public.tiers enable row level security;
alter table public.merchants enable row level security;
alter table public.merchant_staff enable row level security;
alter table public.subscriptions enable row level security;
alter table public.subscription_events enable row level security;
alter table public.programs enable row level security;
alter table public.rewards enable row level security;
alter table public.cards enable row level security;
alter table public.transactions enable row level security;
alter table public.reward_tokens enable row level security;  -- intentionally no policies: server functions only
alter table public.favorites enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_own_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.is_admin());
create policy profiles_own_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy admins_self_select on public.platform_admins for select to authenticated using (private.is_admin());
create policy settings_read on public.platform_settings for select to authenticated using (true);
create policy settings_admin_write on public.platform_settings for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy plans_read on public.plans for select to authenticated using (is_active or private.is_admin());
create policy plans_admin_write on public.plans for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy tiers_read on public.tiers for select to authenticated using (true);
create policy tiers_admin_write on public.tiers for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy merchants_read on public.merchants for select to authenticated
  using (status = 'approved' or private.is_merchant_member(id) or private.is_admin());
create policy merchants_owner_insert on public.merchants for insert to authenticated
  with check (owner_id = (select auth.uid()) and status = 'pending');
create policy merchants_update on public.merchants for update to authenticated
  using (private.is_merchant_owner(id) or private.is_admin())
  with check (private.is_merchant_owner(id) or private.is_admin());
create policy staff_read on public.merchant_staff for select to authenticated
  using (user_id = (select auth.uid()) or private.is_merchant_owner(merchant_id) or private.is_admin());
create policy staff_owner_write on public.merchant_staff for all to authenticated
  using (private.is_merchant_owner(merchant_id)) with check (private.is_merchant_owner(merchant_id));
create policy subs_read on public.subscriptions for select to authenticated
  using (private.is_merchant_owner(merchant_id) or private.is_admin());
create policy subs_admin_write on public.subscriptions for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy subev_read on public.subscription_events for select to authenticated using (private.is_admin());
create policy programs_read on public.programs for select to authenticated
  using (private.is_merchant_member(merchant_id) or private.is_admin()
         or (status = 'active' and exists (select 1 from public.merchants m where m.id = merchant_id and m.status = 'approved')));
create policy programs_owner_insert on public.programs for insert to authenticated
  with check (private.is_merchant_owner(merchant_id));
create policy programs_owner_update on public.programs for update to authenticated
  using (private.is_merchant_owner(merchant_id)) with check (private.is_merchant_owner(merchant_id));
create policy rewards_read on public.rewards for select to authenticated
  using (private.is_merchant_member(merchant_id) or private.is_admin()
         or (is_active and exists (select 1 from public.merchants m where m.id = merchant_id and m.status = 'approved')));
create policy rewards_owner_insert on public.rewards for insert to authenticated
  with check (private.is_merchant_owner(merchant_id)
    and exists (select 1 from public.programs p where p.id = program_id and p.merchant_id = rewards.merchant_id));
create policy rewards_owner_update on public.rewards for update to authenticated
  using (private.is_merchant_owner(merchant_id)) with check (private.is_merchant_owner(merchant_id));
create policy cards_read on public.cards for select to authenticated
  using (customer_id = (select auth.uid()) or private.is_merchant_owner(merchant_id) or private.is_admin());
create policy tx_read on public.transactions for select to authenticated
  using (customer_id = (select auth.uid()) or private.is_merchant_owner(merchant_id) or private.is_admin());
create policy fav_own on public.favorites for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy audit_admin_read on public.audit_logs for select to authenticated using (private.is_admin());

-- Reference/config data (not demo data). Placeholders must be confirmed by the owner.
insert into public.platform_settings(key, value) values
  ('trial_days', '14'), ('default_grace_days', '3'), ('otp_channels', '["sms","whatsapp"]');
insert into public.plans(code, name_ar, price_usd, is_active, sort_order) values
  ('starter','الباقة الأولية',10,false,1), ('pro','الباقة الاحترافية',20,false,2), ('advanced','الباقة المتقدمة',35,false,3);
insert into public.tiers(code, name_ar, min_earns_12m, sort_order) values
  ('bronze','برونزي',0,1), ('silver','فضي',10,2), ('gold','ذهبي',30,3);
