create extension if not exists pgcrypto with schema extensions; create schema if not exists private; revoke all on schema private from public,anon; grant usage on schema private to authenticated;
alter default privileges for role postgres in schema public revoke all on tables from anon,authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon,authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from public,anon,authenticated;
alter default privileges for role postgres in schema private revoke all on tables from public,anon,authenticated;
alter default privileges for role postgres in schema private revoke execute on functions from public,anon,authenticated;

create type public.account_role as enum ('customer', 'merchant_owner', 'merchant_admin', 'merchant_staff', 'platform_admin');

create type public.ledger_kind as enum ('earn', 'redeem', 'adjustment', 'reversal', 'expiry');

create type public.loyalty_program_kind as enum ('points', 'stamps');

create type public.merchant_state as enum ('pending', 'active', 'suspended', 'rejected');

create type public.program_state as enum ('draft', 'active', 'paused', 'archived');

create type public.token_purpose as enum ('earn', 'redeem');

create type public.token_state as enum ('issued', 'consumed', 'expired', 'revoked');

create table public.audit_events (id bigint generated always as identity not null,
actor_user_id uuid,
merchant_id uuid,
action text not null,
entity_type text not null,
entity_id text,
request_id uuid,
details jsonb default '{}'::jsonb not null,
created_at timestamp with time zone default now() not null);

create table public.favorites (customer_id uuid not null,
merchant_id uuid not null,
created_at timestamp with time zone default now() not null);

create table public.loyalty_accounts (id uuid default gen_random_uuid() not null,
customer_id uuid not null,
merchant_id uuid not null,
program_id uuid not null,
points_balance bigint default 0 not null,
stamps_balance integer default 0 not null,
lifetime_points bigint default 0 not null,
lifetime_stamps bigint default 0 not null,
joined_at timestamp with time zone default now() not null,
last_activity_at timestamp with time zone);

create table public.loyalty_ledger (id uuid default gen_random_uuid() not null,
account_id uuid not null,
customer_id uuid not null,
merchant_id uuid not null,
program_id uuid not null,
kind ledger_kind not null,
points_delta bigint default 0 not null,
stamps_delta integer default 0 not null,
points_after bigint not null,
stamps_after integer not null,
reference text,
idempotency_key text not null,
program_version integer not null,
actor_user_id uuid,
metadata jsonb default '{}'::jsonb not null,
created_at timestamp with time zone default now() not null);

create table public.loyalty_programs (id uuid default gen_random_uuid() not null,
merchant_id uuid not null,
name text not null,
kind loyalty_program_kind not null,
state program_state default 'draft'::program_state not null,
description text,
currency_code character(3) default 'YER'::bpchar not null,
points_per_currency numeric(12,4) default 1 not null,
stamp_goal integer default 10 not null,
rules jsonb default '{}'::jsonb not null,
version integer default 1 not null,
starts_at timestamp with time zone,
ends_at timestamp with time zone,
created_at timestamp with time zone default now() not null,
updated_at timestamp with time zone default now() not null);

create table public.loyalty_tokens (id uuid default gen_random_uuid() not null,
merchant_id uuid not null,
program_id uuid not null,
account_id uuid not null,
purpose token_purpose not null,
token_digest text not null,
state token_state default 'issued'::token_state not null,
quantity integer default 1 not null,
reward_id uuid,
created_by uuid not null,
expires_at timestamp with time zone not null,
consumed_at timestamp with time zone,
created_at timestamp with time zone default now() not null);

create table public.merchant_invites (id uuid default gen_random_uuid() not null,
merchant_id uuid not null,
phone_e164 text not null,
permissions text[] default ARRAY['issue_earn'::text] not null,
invite_digest text not null,
created_by uuid not null,
expires_at timestamp with time zone not null,
accepted_by uuid,
accepted_at timestamp with time zone,
revoked_at timestamp with time zone,
created_at timestamp with time zone default now() not null);

create table public.merchant_members (merchant_id uuid not null,
user_id uuid not null,
role text not null,
permissions text[] default '{}'::text[] not null,
is_active boolean default true not null,
invited_by uuid,
created_at timestamp with time zone default now() not null);

create table public.merchants (id uuid default gen_random_uuid() not null,
owner_user_id uuid not null,
name text not null,
slug text not null,
category text,
description text,
logo_path text,
cover_path text,
country_code character(2) default 'YE'::bpchar not null,
city text,
address text,
phone text,
email text,
status merchant_state default 'pending'::merchant_state not null,
timezone text default 'Asia/Aden'::text not null,
created_at timestamp with time zone default now() not null,
updated_at timestamp with time zone default now() not null);

create table public.platform_admins (user_id uuid not null,
created_at timestamp with time zone default now() not null);

create table public.platform_settings (key text not null,
value jsonb not null,
updated_at timestamp with time zone default now() not null);

create table public.profiles (id uuid not null,
full_name text,
phone_e164 text,
preferred_locale text default 'ar'::text not null,
avatar_path text,
created_at timestamp with time zone default now() not null,
updated_at timestamp with time zone default now() not null);

create table public.rewards (id uuid default gen_random_uuid() not null,
merchant_id uuid not null,
program_id uuid not null,
title text not null,
description text,
image_path text,
points_cost integer,
stamps_cost integer,
stock_quantity integer,
is_active boolean default true not null,
created_at timestamp with time zone default now() not null);

alter table public.audit_events add constraint audit_events_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id);

alter table public.audit_events add constraint audit_events_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES merchants(id);

alter table public.audit_events add constraint audit_events_pkey PRIMARY KEY (id);

alter table public.favorites add constraint favorites_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public.favorites add constraint favorites_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE;

alter table public.favorites add constraint favorites_pkey PRIMARY KEY (customer_id, merchant_id);

alter table public.loyalty_accounts add constraint loyalty_accounts_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public.loyalty_accounts add constraint loyalty_accounts_customer_id_program_id_key UNIQUE (customer_id, program_id);

alter table public.loyalty_accounts add constraint loyalty_accounts_id_merchant_id_program_id_key UNIQUE (id, merchant_id, program_id);

alter table public.loyalty_accounts add constraint loyalty_accounts_lifetime_points_check CHECK ((lifetime_points >= 0));

alter table public.loyalty_accounts add constraint loyalty_accounts_lifetime_stamps_check CHECK ((lifetime_stamps >= 0));

alter table public.loyalty_accounts add constraint loyalty_accounts_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE;

alter table public.loyalty_accounts add constraint loyalty_accounts_merchant_id_program_id_fkey FOREIGN KEY (merchant_id, program_id) REFERENCES loyalty_programs(merchant_id, id) ON DELETE CASCADE;

alter table public.loyalty_accounts add constraint loyalty_accounts_pkey PRIMARY KEY (id);

alter table public.loyalty_accounts add constraint loyalty_accounts_points_balance_check CHECK ((points_balance >= 0));

alter table public.loyalty_accounts add constraint loyalty_accounts_program_id_fkey FOREIGN KEY (program_id) REFERENCES loyalty_programs(id) ON DELETE CASCADE;

alter table public.loyalty_accounts add constraint loyalty_accounts_stamps_balance_check CHECK ((stamps_balance >= 0));

alter table public.loyalty_ledger add constraint loyalty_ledger_account_id_fkey FOREIGN KEY (account_id) REFERENCES loyalty_accounts(id);

alter table public.loyalty_ledger add constraint loyalty_ledger_account_id_merchant_id_program_id_fkey FOREIGN KEY (account_id, merchant_id, program_id) REFERENCES loyalty_accounts(id, merchant_id, program_id);

alter table public.loyalty_ledger add constraint loyalty_ledger_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id);

alter table public.loyalty_ledger add constraint loyalty_ledger_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES auth.users(id);

alter table public.loyalty_ledger add constraint loyalty_ledger_idempotency_key_key UNIQUE (idempotency_key);

alter table public.loyalty_ledger add constraint loyalty_ledger_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES merchants(id);

alter table public.loyalty_ledger add constraint loyalty_ledger_pkey PRIMARY KEY (id);

alter table public.loyalty_ledger add constraint loyalty_ledger_points_after_check CHECK ((points_after >= 0));

alter table public.loyalty_ledger add constraint loyalty_ledger_program_id_fkey FOREIGN KEY (program_id) REFERENCES loyalty_programs(id);

alter table public.loyalty_ledger add constraint loyalty_ledger_stamps_after_check CHECK ((stamps_after >= 0));

alter table public.loyalty_programs add constraint loyalty_programs_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE;

alter table public.loyalty_programs add constraint loyalty_programs_merchant_id_id_key UNIQUE (merchant_id, id);

alter table public.loyalty_programs add constraint loyalty_programs_name_check CHECK (((char_length(TRIM(BOTH FROM name)) >= 2) AND (char_length(TRIM(BOTH FROM name)) <= 100)));

alter table public.loyalty_programs add constraint loyalty_programs_pkey PRIMARY KEY (id);

alter table public.loyalty_programs add constraint loyalty_programs_points_per_currency_check CHECK ((points_per_currency > (0)::numeric));

alter table public.loyalty_programs add constraint loyalty_programs_stamp_goal_check CHECK (((stamp_goal >= 2) AND (stamp_goal <= 100)));

alter table public.loyalty_programs add constraint loyalty_programs_version_check CHECK ((version > 0));

alter table public.loyalty_tokens add constraint loyalty_tokens_account_id_fkey FOREIGN KEY (account_id) REFERENCES loyalty_accounts(id) ON DELETE CASCADE;

alter table public.loyalty_tokens add constraint loyalty_tokens_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);

alter table public.loyalty_tokens add constraint loyalty_tokens_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE;

alter table public.loyalty_tokens add constraint loyalty_tokens_pkey PRIMARY KEY (id);

alter table public.loyalty_tokens add constraint loyalty_tokens_program_id_fkey FOREIGN KEY (program_id) REFERENCES loyalty_programs(id) ON DELETE CASCADE;

alter table public.loyalty_tokens add constraint loyalty_tokens_quantity_check CHECK ((quantity > 0));

alter table public.loyalty_tokens add constraint loyalty_tokens_reward_id_fkey FOREIGN KEY (reward_id) REFERENCES rewards(id);

alter table public.loyalty_tokens add constraint loyalty_tokens_token_digest_key UNIQUE (token_digest);

alter table public.merchant_invites add constraint merchant_invites_accepted_by_fkey FOREIGN KEY (accepted_by) REFERENCES auth.users(id);

alter table public.merchant_invites add constraint merchant_invites_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);

alter table public.merchant_invites add constraint merchant_invites_invite_digest_key UNIQUE (invite_digest);

alter table public.merchant_invites add constraint merchant_invites_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE;

alter table public.merchant_invites add constraint merchant_invites_permissions_check CHECK ((permissions <@ ARRAY['issue_earn'::text, 'confirm_redeem'::text, 'view_analytics'::text]));

alter table public.merchant_invites add constraint merchant_invites_phone_e164_check CHECK ((phone_e164 ~ '^\+[1-9][0-9]{7,14}$'::text));

alter table public.merchant_invites add constraint merchant_invites_pkey PRIMARY KEY (id);

alter table public.merchant_members add constraint merchant_member_permissions_allowed CHECK ((permissions <@ ARRAY['manage_programs'::text, 'manage_rewards'::text, 'manage_staff'::text, 'issue_earn'::text, 'confirm_redeem'::text, 'view_analytics'::text]));

alter table public.merchant_members add constraint merchant_members_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES auth.users(id);

alter table public.merchant_members add constraint merchant_members_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE;

alter table public.merchant_members add constraint merchant_members_pkey PRIMARY KEY (merchant_id, user_id);

alter table public.merchant_members add constraint merchant_members_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'admin'::text, 'manager'::text, 'staff'::text])));

alter table public.merchant_members add constraint merchant_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public.merchants add constraint merchants_name_check CHECK (((char_length(TRIM(BOTH FROM name)) >= 2) AND (char_length(TRIM(BOTH FROM name)) <= 120)));

alter table public.merchants add constraint merchants_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id);

alter table public.merchants add constraint merchants_pkey PRIMARY KEY (id);

alter table public.merchants add constraint merchants_slug_key UNIQUE (slug);

alter table public.platform_admins add constraint platform_admins_pkey PRIMARY KEY (user_id);

alter table public.platform_admins add constraint platform_admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public.platform_settings add constraint platform_settings_pkey PRIMARY KEY (key);

alter table public.profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public.profiles add constraint profiles_pkey PRIMARY KEY (id);

alter table public.profiles add constraint profiles_preferred_locale_check CHECK ((preferred_locale = ANY (ARRAY['ar'::text, 'en'::text])));

alter table public.rewards add constraint rewards_cost_matches_program CHECK ((((points_cost IS NOT NULL) AND (stamps_cost IS NULL)) OR ((points_cost IS NULL) AND (stamps_cost IS NOT NULL))));

alter table public.rewards add constraint rewards_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE;

alter table public.rewards add constraint rewards_merchant_id_program_id_fkey FOREIGN KEY (merchant_id, program_id) REFERENCES loyalty_programs(merchant_id, id) ON DELETE CASCADE;

alter table public.rewards add constraint rewards_pkey PRIMARY KEY (id);

alter table public.rewards add constraint rewards_points_cost_check CHECK (((points_cost IS NULL) OR (points_cost > 0)));

alter table public.rewards add constraint rewards_program_id_fkey FOREIGN KEY (program_id) REFERENCES loyalty_programs(id) ON DELETE CASCADE;

alter table public.rewards add constraint rewards_program_id_id_key UNIQUE (program_id, id);

alter table public.rewards add constraint rewards_stamps_cost_check CHECK (((stamps_cost IS NULL) OR (stamps_cost > 0)));

alter table public.rewards add constraint rewards_stock_quantity_check CHECK (((stock_quantity IS NULL) OR (stock_quantity >= 0)));

alter table public.rewards add constraint rewards_title_check CHECK (((char_length(TRIM(BOTH FROM title)) >= 2) AND (char_length(TRIM(BOTH FROM title)) <= 120)));

CREATE INDEX audit_events_merchant_time_idx ON public.audit_events USING btree (merchant_id, created_at DESC);

CREATE INDEX audit_events_actor_idx ON public.audit_events USING btree (actor_user_id);

CREATE INDEX favorites_merchant_idx ON public.favorites USING btree (merchant_id);

CREATE INDEX loyalty_accounts_customer_idx ON public.loyalty_accounts USING btree (customer_id, last_activity_at DESC);

CREATE INDEX loyalty_accounts_merchant_idx ON public.loyalty_accounts USING btree (merchant_id, last_activity_at DESC);

CREATE INDEX loyalty_accounts_program_idx ON public.loyalty_accounts USING btree (program_id);

CREATE INDEX loyalty_accounts_merchant_program_idx ON public.loyalty_accounts USING btree (merchant_id, program_id);

CREATE INDEX loyalty_ledger_customer_time_idx ON public.loyalty_ledger USING btree (customer_id, created_at DESC);

CREATE INDEX loyalty_ledger_merchant_time_idx ON public.loyalty_ledger USING btree (merchant_id, created_at DESC);

CREATE INDEX loyalty_ledger_account_idx ON public.loyalty_ledger USING btree (account_id);

CREATE INDEX loyalty_ledger_program_idx ON public.loyalty_ledger USING btree (program_id);

CREATE INDEX loyalty_ledger_actor_idx ON public.loyalty_ledger USING btree (actor_user_id);

CREATE INDEX loyalty_ledger_account_merchant_program_idx ON public.loyalty_ledger USING btree (account_id, merchant_id, program_id);

CREATE INDEX loyalty_programs_merchant_state_idx ON public.loyalty_programs USING btree (merchant_id, state);

CREATE INDEX loyalty_tokens_account_idx ON public.loyalty_tokens USING btree (account_id);

CREATE INDEX loyalty_tokens_program_idx ON public.loyalty_tokens USING btree (program_id);

CREATE INDEX loyalty_tokens_creator_idx ON public.loyalty_tokens USING btree (created_by);

CREATE INDEX loyalty_tokens_reward_idx ON public.loyalty_tokens USING btree (reward_id);

CREATE INDEX loyalty_tokens_active_idx ON public.loyalty_tokens USING btree (merchant_id, expires_at) WHERE (state = 'issued'::token_state);

CREATE UNIQUE INDEX loyalty_tokens_one_open_per_account_purpose ON public.loyalty_tokens USING btree (account_id, purpose) WHERE (state = 'issued'::token_state);

CREATE INDEX merchant_invites_merchant_idx ON public.merchant_invites USING btree (merchant_id, created_at DESC);

CREATE INDEX merchant_members_user_idx ON public.merchant_members USING btree (user_id, is_active);

CREATE INDEX merchant_members_inviter_idx ON public.merchant_members USING btree (invited_by);

CREATE INDEX merchants_status_created_idx ON public.merchants USING btree (status, created_at DESC);

CREATE INDEX merchants_owner_idx ON public.merchants USING btree (owner_user_id);

CREATE INDEX rewards_program_active_idx ON public.rewards USING btree (program_id, is_active);

CREATE INDEX rewards_merchant_idx ON public.rewards USING btree (merchant_id);

CREATE INDEX rewards_merchant_program_idx ON public.rewards USING btree (merchant_id, program_id);

CREATE OR REPLACE FUNCTION private.bootstrap_merchant_owner()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  insert into public.merchant_members(merchant_id,user_id,role,permissions)
  values(new.id,new.owner_user_id,'owner',array['manage_programs','manage_rewards','manage_staff','issue_earn','confirm_redeem','view_analytics'])
  on conflict(merchant_id,user_id) do update set role='owner',is_active=true;
  return new;
end;
$function$


CREATE OR REPLACE FUNCTION private.bump_program_version()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  if new.rules is distinct from old.rules
     or new.kind is distinct from old.kind
     or new.points_per_currency is distinct from old.points_per_currency
     or new.stamp_goal is distinct from old.stamp_goal then
    new.version := old.version + 1;
  end if;
  return new;
end;
$function$


CREATE OR REPLACE FUNCTION private.can_confirm_redeem(p_merchant_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select exists(select 1 from public.merchant_members mm where mm.merchant_id=p_merchant_id and mm.user_id=(select auth.uid()) and mm.is_active and (mm.role in ('owner','admin','manager') or 'confirm_redeem'=any(mm.permissions)));
$function$


CREATE OR REPLACE FUNCTION private.can_issue_earn(p_merchant_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select exists(select 1 from public.merchant_members mm where mm.merchant_id=p_merchant_id and mm.user_id=(select auth.uid()) and mm.is_active and (mm.role in ('owner','admin','manager') or 'issue_earn'=any(mm.permissions)));
$function$


CREATE OR REPLACE FUNCTION private.can_manage_merchant(p_merchant_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ select exists(select 1 from public.merchant_members mm where mm.merchant_id=p_merchant_id and mm.user_id=(select auth.uid()) and mm.is_active and mm.role in ('owner','admin','manager')); $function$


CREATE OR REPLACE FUNCTION private.guard_merchant_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if new.status is distinct from old.status and not private.is_platform_admin() then
  raise exception 'only platform administrators may change merchant status' using errcode='42501';
 end if;
 if new.status is distinct from old.status then
  insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details)
  values((select auth.uid()),old.id,'merchant.status_changed','merchant',old.id::text,jsonb_build_object('from',old.status,'to',new.status));
 end if;
 return new;
end;
$function$


CREATE OR REPLACE FUNCTION private.is_merchant_member(p_merchant_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ select exists(select 1 from public.merchant_members mm where mm.merchant_id=p_merchant_id and mm.user_id=(select auth.uid()) and mm.is_active); $function$


CREATE OR REPLACE FUNCTION private.is_platform_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ select exists(select 1 from public.platform_admins a where a.user_id=(select auth.uid())); $function$


CREATE OR REPLACE FUNCTION private.on_auth_user_created()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name')) on conflict(id) do nothing; return new; end; $function$


CREATE OR REPLACE FUNCTION private.prevent_audit_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ begin raise exception 'audit events are immutable'; end; $function$


CREATE OR REPLACE FUNCTION private.prevent_ledger_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ begin raise exception 'loyalty ledger is immutable'; end; $function$


CREATE OR REPLACE FUNCTION private.touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ begin new.updated_at=now(); return new; end; $function$


CREATE OR REPLACE FUNCTION public.accept_merchant_invite(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_invite public.merchant_invites%rowtype; v_phone text;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_code is null or p_code !~ '^[A-F0-9]{16}$' then return jsonb_build_object('ok',false,'error','invalid_code'); end if;
 select phone into v_phone from auth.users where id=(select auth.uid());
 select * into v_invite from public.merchant_invites i
 where i.invite_digest=encode(extensions.digest(upper(p_code),'sha256'),'hex') for update;
 if not found then return jsonb_build_object('ok',false,'error','invite_unavailable'); end if;
 if v_invite.accepted_at is not null or v_invite.revoked_at is not null then return jsonb_build_object('ok',false,'error','invite_used'); end if;
 if v_invite.expires_at<=now() then return jsonb_build_object('ok',false,'error','invite_expired'); end if;
 if v_phone is null or v_phone<>v_invite.phone_e164 then return jsonb_build_object('ok',false,'error','phone_mismatch'); end if;
 insert into public.merchant_members(merchant_id,user_id,role,permissions,is_active,invited_by)
 values(v_invite.merchant_id,(select auth.uid()),'staff',v_invite.permissions,true,v_invite.created_by)
 on conflict(merchant_id,user_id) do update set role='staff',permissions=excluded.permissions,is_active=true,invited_by=excluded.invited_by;
 update public.merchant_invites set accepted_by=(select auth.uid()),accepted_at=now() where id=v_invite.id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id)
 values((select auth.uid()),v_invite.merchant_id,'merchant.staff_joined','merchant_member',(select auth.uid())::text);
 return jsonb_build_object('ok',true,'merchant_id',v_invite.merchant_id,'permissions',v_invite.permissions);
end;
$function$


CREATE OR REPLACE FUNCTION public.confirm_earn_code(p_code text, p_purchase_amount numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_token public.loyalty_tokens%rowtype; v_account public.loyalty_accounts%rowtype; v_program public.loyalty_programs%rowtype;
 v_points bigint:=0; v_stamps integer:=0; v_key text; v_min_purchase numeric:=0; v_merchant_status public.merchant_state;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_code is null or p_code !~ '^[A-F0-9]{16}$' then return jsonb_build_object('ok',false,'error','invalid_code'); end if;
 if p_purchase_amount is null or p_purchase_amount<=0 or p_purchase_amount>100000000 then return jsonb_build_object('ok',false,'error','invalid_purchase_amount'); end if;
 select * into v_token from public.loyalty_tokens t where t.token_digest=encode(extensions.digest(upper(p_code),'sha256'),'hex') and t.purpose='earn' for update;
 if not found then return jsonb_build_object('ok',false,'error','code_unavailable'); end if;
 if not private.can_issue_earn(v_token.merchant_id) then return jsonb_build_object('ok',false,'error','not_authorized'); end if;
 if v_token.state<>'issued' then return jsonb_build_object('ok',false,'error','code_used'); end if;
 if v_token.expires_at<=now() then update public.loyalty_tokens set state='expired' where id=v_token.id; return jsonb_build_object('ok',false,'error','code_expired'); end if;
 select status into v_merchant_status from public.merchants where id=v_token.merchant_id;
 if v_merchant_status<>'active' then return jsonb_build_object('ok',false,'error','merchant_unavailable'); end if;
 select * into v_account from public.loyalty_accounts where id=v_token.account_id for update;
 select * into v_program from public.loyalty_programs where id=v_token.program_id;
 if v_program.state<>'active' then return jsonb_build_object('ok',false,'error','program_unavailable'); end if;
 if v_program.kind='points' then v_points:=floor(p_purchase_amount*v_program.points_per_currency)::bigint; if v_points<1 then return jsonb_build_object('ok',false,'error','purchase_below_earning_threshold'); end if;
 else v_min_purchase:=coalesce((v_program.rules->>'minimum_purchase')::numeric,0); if p_purchase_amount<v_min_purchase then return jsonb_build_object('ok',false,'error','purchase_below_earning_threshold'); end if; v_stamps:=1; end if;
 update public.loyalty_accounts set points_balance=points_balance+v_points,stamps_balance=stamps_balance+v_stamps,lifetime_points=lifetime_points+v_points,lifetime_stamps=lifetime_stamps+v_stamps,last_activity_at=now() where id=v_account.id returning * into v_account;
 v_key:='earn:'||v_token.id::text;
 insert into public.loyalty_ledger(account_id,customer_id,merchant_id,program_id,kind,points_delta,stamps_delta,points_after,stamps_after,reference,idempotency_key,program_version,actor_user_id,metadata)
 values(v_account.id,v_account.customer_id,v_account.merchant_id,v_account.program_id,'earn',v_points,v_stamps,v_account.points_balance,v_account.stamps_balance,'purchase',v_key,v_program.version,(select auth.uid()),jsonb_build_object('purchase_amount',p_purchase_amount,'currency',v_program.currency_code));
 update public.loyalty_tokens set state='consumed',consumed_at=now() where id=v_token.id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details) values((select auth.uid()),v_token.merchant_id,'loyalty.earn_confirmed','loyalty_token',v_token.id::text,jsonb_build_object('purchase_amount',p_purchase_amount));
 return jsonb_build_object('ok',true,'points_balance',v_account.points_balance,'stamps_balance',v_account.stamps_balance,'points_added',v_points,'stamps_added',v_stamps);
end;
$function$


CREATE OR REPLACE FUNCTION public.confirm_redeem_code(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_token public.loyalty_tokens%rowtype; v_account public.loyalty_accounts%rowtype; v_reward public.rewards%rowtype; v_program public.loyalty_programs%rowtype; v_points bigint:=0; v_stamps integer:=0; v_merchant_status public.merchant_state;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_code is null or p_code !~ '^[A-F0-9]{16}$' then return jsonb_build_object('ok',false,'error','invalid_code'); end if;
 select * into v_token from public.loyalty_tokens t where t.token_digest=encode(extensions.digest(upper(p_code),'sha256'),'hex') and t.purpose='redeem' for update;
 if not found then return jsonb_build_object('ok',false,'error','code_unavailable'); end if;
 if not private.can_confirm_redeem(v_token.merchant_id) then return jsonb_build_object('ok',false,'error','not_authorized'); end if;
 if v_token.state<>'issued' then return jsonb_build_object('ok',false,'error','code_used'); end if;
 if v_token.expires_at<=now() then update public.loyalty_tokens set state='expired' where id=v_token.id; return jsonb_build_object('ok',false,'error','code_expired'); end if;
 select status into v_merchant_status from public.merchants where id=v_token.merchant_id;
 if v_merchant_status<>'active' then return jsonb_build_object('ok',false,'error','merchant_unavailable'); end if;
 select * into v_account from public.loyalty_accounts where id=v_token.account_id for update;
 select * into v_reward from public.rewards where id=v_token.reward_id and is_active for update;
 if v_reward.id is null then return jsonb_build_object('ok',false,'error','reward_unavailable'); end if;
 select * into v_program from public.loyalty_programs where id=v_token.program_id and state='active';
 if not found then return jsonb_build_object('ok',false,'error','program_unavailable'); end if;
 if v_program.kind='points' then v_points:=coalesce(v_reward.points_cost,0); else v_stamps:=coalesce(v_reward.stamps_cost,0); end if;
 if v_points>v_account.points_balance or v_stamps>v_account.stamps_balance then return jsonb_build_object('ok',false,'error','insufficient_balance'); end if;
 if v_reward.stock_quantity is not null then update public.rewards set stock_quantity=stock_quantity-1 where id=v_reward.id and stock_quantity>0; if not found then return jsonb_build_object('ok',false,'error','out_of_stock'); end if; end if;
 update public.loyalty_accounts set points_balance=points_balance-v_points,stamps_balance=stamps_balance-v_stamps,last_activity_at=now() where id=v_account.id returning * into v_account;
 insert into public.loyalty_ledger(account_id,customer_id,merchant_id,program_id,kind,points_delta,stamps_delta,points_after,stamps_after,reference,idempotency_key,program_version,actor_user_id,metadata)
 values(v_account.id,v_account.customer_id,v_account.merchant_id,v_account.program_id,'redeem',-v_points,-v_stamps,v_account.points_balance,v_account.stamps_balance,v_reward.title,'redeem:'||v_token.id::text,v_program.version,(select auth.uid()),jsonb_build_object('reward_id',v_reward.id));
 update public.loyalty_tokens set state='consumed',consumed_at=now() where id=v_token.id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id) values((select auth.uid()),v_token.merchant_id,'loyalty.redeem_confirmed','loyalty_token',v_token.id::text);
 return jsonb_build_object('ok',true,'points_balance',v_account.points_balance,'stamps_balance',v_account.stamps_balance,'reward',v_reward.title);
end;
$function$


CREATE OR REPLACE FUNCTION public.create_customer_checkin_code(p_program_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_account public.loyalty_accounts%rowtype; v_code text; v_ttl integer:=120; v_merchant_status public.merchant_state;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 select a.* into v_account from public.loyalty_accounts a
 join public.loyalty_programs p on p.id=a.program_id
 where a.customer_id=(select auth.uid()) and a.program_id=p_program_id and p.state='active'
 for update of a;
 if not found then return jsonb_build_object('ok',false,'error','account_not_found'); end if;
 select status into v_merchant_status from public.merchants where id=v_account.merchant_id;
 if v_merchant_status<>'active' then return jsonb_build_object('ok',false,'error','merchant_unavailable'); end if;
 update public.loyalty_tokens set state='expired' where account_id=v_account.id and purpose='earn' and state='issued' and expires_at<=now();
 v_code:=upper(substr(encode(extensions.gen_random_bytes(16),'hex'),1,16));
 insert into public.loyalty_tokens(merchant_id,program_id,account_id,purpose,token_digest,quantity,created_by,expires_at)
 values(v_account.merchant_id,v_account.program_id,v_account.id,'earn',encode(extensions.digest(v_code,'sha256'),'hex'),1,(select auth.uid()),now()+make_interval(secs=>v_ttl));
 return jsonb_build_object('ok',true,'code',v_code,'expires_in',v_ttl);
end;
$function$


CREATE OR REPLACE FUNCTION public.create_merchant_invite(p_merchant_id uuid, p_phone_e164 text, p_permissions text[] DEFAULT ARRAY['issue_earn'::text])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_code text; v_id uuid;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.can_manage_merchant(p_merchant_id) then return jsonb_build_object('ok',false,'error','not_authorized'); end if;
 if p_phone_e164 is null or p_phone_e164 !~ '^\+[1-9][0-9]{7,14}$' then return jsonb_build_object('ok',false,'error','invalid_phone'); end if;
 if p_permissions is null or cardinality(p_permissions)=0 or not (p_permissions <@ array['issue_earn','confirm_redeem','view_analytics']::text[]) then
  return jsonb_build_object('ok',false,'error','invalid_permissions');
 end if;
 v_code:=upper(substr(encode(extensions.gen_random_bytes(16),'hex'),1,16));
 insert into public.merchant_invites(merchant_id,phone_e164,permissions,invite_digest,created_by,expires_at)
 values(p_merchant_id,p_phone_e164,p_permissions,encode(extensions.digest(v_code,'sha256'),'hex'),(select auth.uid()),now()+interval '48 hours')
 returning id into v_id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id)
 values((select auth.uid()),p_merchant_id,'merchant.staff_invited','merchant_invite',v_id::text);
 return jsonb_build_object('ok',true,'invite_id',v_id,'code',v_code,'expires_in_hours',48);
end;
$function$


CREATE OR REPLACE FUNCTION public.create_redeem_code(p_account_id uuid, p_reward_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_account public.loyalty_accounts%rowtype; v_reward public.rewards%rowtype; v_program public.loyalty_programs%rowtype;
        v_code text; v_ttl integer:=300; v_merchant_status public.merchant_state;
begin
  if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
  select * into v_account from public.loyalty_accounts where id=p_account_id and customer_id=(select auth.uid()) for update;
  if not found then return jsonb_build_object('ok',false,'error','account_not_found'); end if;
  select status into v_merchant_status from public.merchants where id=v_account.merchant_id;
  if v_merchant_status<>'active' then return jsonb_build_object('ok',false,'error','merchant_unavailable'); end if;
  select * into v_reward from public.rewards where id=p_reward_id and program_id=v_account.program_id and merchant_id=v_account.merchant_id and is_active;
  if not found then return jsonb_build_object('ok',false,'error','reward_unavailable'); end if;
  select * into v_program from public.loyalty_programs where id=v_account.program_id and state='active';
  if not found then return jsonb_build_object('ok',false,'error','program_unavailable'); end if;
  if (v_program.kind='points' and coalesce(v_reward.points_cost,0)>v_account.points_balance)
     or (v_program.kind='stamps' and coalesce(v_reward.stamps_cost,0)>v_account.stamps_balance) then
    return jsonb_build_object('ok',false,'error','insufficient_balance');
  end if;
  update public.loyalty_tokens set state='expired' where account_id=v_account.id and purpose='redeem' and state='issued' and expires_at<=now();
  v_code:=upper(substr(encode(extensions.gen_random_bytes(16),'hex'),1,16));
  insert into public.loyalty_tokens(merchant_id,program_id,account_id,purpose,token_digest,reward_id,created_by,expires_at)
  values(v_account.merchant_id,v_account.program_id,v_account.id,'redeem',
    encode(extensions.digest(v_code,'sha256'),'hex'),v_reward.id,(select auth.uid()),now()+make_interval(secs=>v_ttl));
  return jsonb_build_object('ok',true,'code',v_code,'expires_in',v_ttl);
end;
$function$


CREATE OR REPLACE FUNCTION public.join_loyalty_program(p_program_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_program public.loyalty_programs%rowtype; v_account uuid;
begin
  if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
  select p.* into v_program from public.loyalty_programs p
  join public.merchants m on m.id=p.merchant_id
  where p.id=p_program_id and p.state='active' and m.status='active';
  if not found then raise exception 'program unavailable' using errcode='P0002'; end if;
  insert into public.loyalty_accounts(customer_id,merchant_id,program_id)
  values((select auth.uid()),v_program.merchant_id,v_program.id)
  on conflict(customer_id,program_id) do nothing;
  select id into v_account from public.loyalty_accounts
  where customer_id=(select auth.uid()) and program_id=p_program_id;
  return v_account;
end;
$function$


CREATE OR REPLACE FUNCTION public.list_merchant_members(p_merchant_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_result jsonb;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.can_manage_merchant(p_merchant_id) then return jsonb_build_object('ok',false,'error','not_authorized'); end if;
 select coalesce(jsonb_agg(jsonb_build_object('user_id',mm.user_id,'role',mm.role,'permissions',mm.permissions,'is_active',mm.is_active,'phone',u.phone,'created_at',mm.created_at) order by mm.created_at desc),'[]'::jsonb)
 into v_result from public.merchant_members mm join auth.users u on u.id=mm.user_id
 where mm.merchant_id=p_merchant_id;
 return jsonb_build_object('ok',true,'members',v_result);
end;
$function$


CREATE OR REPLACE FUNCTION public.set_merchant_member(p_merchant_id uuid, p_user_id uuid, p_permissions text[] DEFAULT NULL::text[], p_active boolean DEFAULT NULL::boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_member public.merchant_members%rowtype;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.can_manage_merchant(p_merchant_id) then return jsonb_build_object('ok',false,'error','not_authorized'); end if;
 select * into v_member from public.merchant_members where merchant_id=p_merchant_id and user_id=p_user_id for update;
 if not found or v_member.role='owner' then return jsonb_build_object('ok',false,'error','member_unavailable'); end if;
 if p_permissions is not null and (cardinality(p_permissions)=0 or not (p_permissions <@ array['issue_earn','confirm_redeem','view_analytics']::text[])) then
  return jsonb_build_object('ok',false,'error','invalid_permissions');
 end if;
 update public.merchant_members set permissions=coalesce(p_permissions,permissions),is_active=coalesce(p_active,is_active)
 where merchant_id=p_merchant_id and user_id=p_user_id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details)
 values((select auth.uid()),p_merchant_id,'merchant.staff_updated','merchant_member',p_user_id::text,jsonb_build_object('permissions',p_permissions,'active',p_active));
 return jsonb_build_object('ok',true);
end;
$function$


CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION private.on_auth_user_created();

CREATE TRIGGER audit_events_immutable BEFORE DELETE OR UPDATE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION private.prevent_audit_mutation();

CREATE TRIGGER loyalty_ledger_immutable BEFORE DELETE OR UPDATE ON public.loyalty_ledger FOR EACH ROW EXECUTE FUNCTION private.prevent_ledger_mutation();

CREATE TRIGGER loyalty_program_version BEFORE UPDATE ON public.loyalty_programs FOR EACH ROW EXECUTE FUNCTION private.bump_program_version();

CREATE TRIGGER programs_touch BEFORE UPDATE ON public.loyalty_programs FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();

CREATE TRIGGER merchant_owner_membership AFTER INSERT ON public.merchants FOR EACH ROW EXECUTE FUNCTION private.bootstrap_merchant_owner();

CREATE TRIGGER merchants_status_guard BEFORE UPDATE OF status ON public.merchants FOR EACH ROW EXECUTE FUNCTION private.guard_merchant_status();

CREATE TRIGGER merchants_touch BEFORE UPDATE ON public.merchants FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();

CREATE TRIGGER profiles_touch BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();

alter table public.audit_events enable row level security;

alter table public.favorites enable row level security;

alter table public.loyalty_accounts enable row level security;

alter table public.loyalty_ledger enable row level security;

alter table public.loyalty_programs enable row level security;

alter table public.loyalty_tokens enable row level security;

alter table public.merchant_invites enable row level security;

alter table public.merchant_members enable row level security;

alter table public.merchants enable row level security;

alter table public.platform_admins enable row level security;

alter table public.platform_settings enable row level security;

alter table public.profiles enable row level security;

alter table public.rewards enable row level security;

create policy audit_admin_read on public.audit_events as permissive for SELECT to authenticated using ((private.is_platform_admin() OR ((merchant_id IS NOT NULL) AND private.can_manage_merchant(merchant_id))));

create policy favorites_owner_all on public.favorites as permissive for ALL to authenticated using ((customer_id = ( SELECT auth.uid() AS uid))) with check ((customer_id = ( SELECT auth.uid() AS uid)));

create policy accounts_customer_or_merchant_read on public.loyalty_accounts as permissive for SELECT to authenticated using (((customer_id = ( SELECT auth.uid() AS uid)) OR private.is_merchant_member(merchant_id) OR private.is_platform_admin()));

create policy ledger_customer_or_merchant_read on public.loyalty_ledger as permissive for SELECT to authenticated using (((customer_id = ( SELECT auth.uid() AS uid)) OR private.is_merchant_member(merchant_id) OR private.is_platform_admin()));

create policy programs_delete_managed on public.loyalty_programs as permissive for DELETE to authenticated using ((private.can_manage_merchant(merchant_id) OR private.is_platform_admin()));

create policy programs_insert_managed on public.loyalty_programs as permissive for INSERT to authenticated with check ((private.can_manage_merchant(merchant_id) OR private.is_platform_admin()));

create policy programs_select_visible on public.loyalty_programs as permissive for SELECT to anon, authenticated using ((((state = 'active'::program_state) AND (EXISTS ( SELECT 1
   FROM merchants m
  WHERE ((m.id = loyalty_programs.merchant_id) AND (m.status = 'active'::merchant_state))))) OR private.is_merchant_member(merchant_id) OR private.is_platform_admin()));

create policy programs_update_managed on public.loyalty_programs as permissive for UPDATE to authenticated using ((private.can_manage_merchant(merchant_id) OR private.is_platform_admin())) with check ((private.can_manage_merchant(merchant_id) OR private.is_platform_admin()));

create policy members_manager_read on public.merchant_members as permissive for SELECT to authenticated using (((user_id = ( SELECT auth.uid() AS uid)) OR private.can_manage_merchant(merchant_id) OR private.is_platform_admin()));

create policy merchants_manager_update on public.merchants as permissive for UPDATE to authenticated using ((private.can_manage_merchant(id) OR private.is_platform_admin())) with check ((private.can_manage_merchant(id) OR private.is_platform_admin()));

create policy merchants_owner_insert on public.merchants as permissive for INSERT to authenticated with check (((owner_user_id = ( SELECT auth.uid() AS uid)) AND (status = 'pending'::merchant_state)));

create policy merchants_select_visible on public.merchants as permissive for SELECT to anon, authenticated using (((status = 'active'::merchant_state) OR (( SELECT auth.uid() AS uid) = owner_user_id) OR private.is_merchant_member(id) OR private.is_platform_admin()));

create policy platform_admin_read_self on public.platform_admins as permissive for SELECT to authenticated using (((user_id = ( SELECT auth.uid() AS uid)) AND private.is_platform_admin()));

create policy settings_admin_only on public.platform_settings as permissive for ALL to authenticated using (private.is_platform_admin()) with check (private.is_platform_admin());

create policy profiles_read_self on public.profiles as permissive for SELECT to authenticated using ((id = ( SELECT auth.uid() AS uid)));

create policy profiles_update_self on public.profiles as permissive for UPDATE to authenticated using ((id = ( SELECT auth.uid() AS uid))) with check ((id = ( SELECT auth.uid() AS uid)));

create policy rewards_delete_managed on public.rewards as permissive for DELETE to authenticated using ((private.can_manage_merchant(merchant_id) OR private.is_platform_admin()));

create policy rewards_insert_managed on public.rewards as permissive for INSERT to authenticated with check ((private.can_manage_merchant(merchant_id) OR private.is_platform_admin()));

create policy rewards_select_visible on public.rewards as permissive for SELECT to anon, authenticated using (((is_active AND (EXISTS ( SELECT 1
   FROM (loyalty_programs p
     JOIN merchants m ON ((m.id = p.merchant_id)))
  WHERE ((p.id = rewards.program_id) AND (p.state = 'active'::program_state) AND (m.status = 'active'::merchant_state))))) OR private.is_merchant_member(merchant_id) OR private.is_platform_admin()));

create policy rewards_update_managed on public.rewards as permissive for UPDATE to authenticated using ((private.can_manage_merchant(merchant_id) OR private.is_platform_admin())) with check ((private.can_manage_merchant(merchant_id) OR private.is_platform_admin()));

create policy wathaq_merchant_branding_delete on storage.objects as permissive for DELETE to authenticated using (((bucket_id = ANY (ARRAY['merchant-branding'::text, 'reward-media'::text])) AND ((storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'::text) AND private.can_manage_merchant(((storage.foldername(name))[1])::uuid)));

create policy wathaq_merchant_branding_insert on storage.objects as permissive for INSERT to authenticated with check (((bucket_id = ANY (ARRAY['merchant-branding'::text, 'reward-media'::text])) AND ((storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'::text) AND private.can_manage_merchant(((storage.foldername(name))[1])::uuid)));

create policy wathaq_merchant_branding_update on storage.objects as permissive for UPDATE to authenticated using (((bucket_id = ANY (ARRAY['merchant-branding'::text, 'reward-media'::text])) AND ((storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'::text) AND private.can_manage_merchant(((storage.foldername(name))[1])::uuid))) with check (((bucket_id = ANY (ARRAY['merchant-branding'::text, 'reward-media'::text])) AND ((storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'::text) AND private.can_manage_merchant(((storage.foldername(name))[1])::uuid)));

create policy wathaq_public_branding_read on storage.objects as permissive for SELECT to anon, authenticated using ((bucket_id = ANY (ARRAY['merchant-branding'::text, 'reward-media'::text])));

revoke all on all tables in schema public from anon,authenticated;
revoke all on all sequences in schema public from anon,authenticated;
grant SELECT on table public.loyalty_programs to anon;

grant SELECT on table public.merchants to anon;

grant SELECT on table public.rewards to anon;

grant SELECT on table public.audit_events to authenticated;

grant DELETE on table public.favorites to authenticated;

grant INSERT on table public.favorites to authenticated;

grant SELECT on table public.favorites to authenticated;

grant SELECT on table public.loyalty_accounts to authenticated;

grant SELECT on table public.loyalty_ledger to authenticated;

grant DELETE on table public.loyalty_programs to authenticated;

grant INSERT on table public.loyalty_programs to authenticated;

grant SELECT on table public.loyalty_programs to authenticated;

grant UPDATE on table public.loyalty_programs to authenticated;

grant SELECT on table public.merchant_members to authenticated;

grant INSERT on table public.merchants to authenticated;

grant SELECT on table public.merchants to authenticated;

grant SELECT on table public.platform_admins to authenticated;

grant SELECT on table public.profiles to authenticated;

grant UPDATE on table public.profiles to authenticated;

grant DELETE on table public.rewards to authenticated;

grant INSERT on table public.rewards to authenticated;

grant SELECT on table public.rewards to authenticated;

grant UPDATE on table public.rewards to authenticated;

grant SELECT (currency_code, state, starts_at, stamp_goal, kind, description, merchant_id, rules, name, created_at, updated_at, version, points_per_currency, ends_at, id) on table public.loyalty_programs to anon;

grant SELECT (phone, category, city, country_code, cover_path, created_at, description, email, id, logo_path, name, owner_user_id, address, slug, status, timezone, updated_at) on table public.merchants to anon;

grant SELECT (is_active, stamps_cost, image_path, id, description, stock_quantity, created_at, points_cost, program_id, merchant_id, title) on table public.rewards to anon;

grant SELECT (details, created_at, actor_user_id, action, id, entity_type, merchant_id, request_id, entity_id) on table public.audit_events to authenticated;

grant INSERT (merchant_id, created_at, customer_id) on table public.favorites to authenticated;

grant SELECT (customer_id, created_at, merchant_id) on table public.favorites to authenticated;

grant SELECT (last_activity_at, joined_at, customer_id, id, stamps_balance, program_id, points_balance, merchant_id, lifetime_stamps, lifetime_points) on table public.loyalty_accounts to authenticated;

grant SELECT (points_after, created_at, points_delta, idempotency_key, account_id, reference, program_version, program_id, actor_user_id, merchant_id, customer_id, metadata, kind, stamps_delta, id, stamps_after) on table public.loyalty_ledger to authenticated;

grant INSERT (created_at, ends_at, version, updated_at, state, starts_at, stamp_goal, rules, id, points_per_currency, name, merchant_id, kind, currency_code, description) on table public.loyalty_programs to authenticated;

grant SELECT (description, starts_at, merchant_id, created_at, state, kind, updated_at, version, currency_code, points_per_currency, ends_at, rules, id, stamp_goal, name) on table public.loyalty_programs to authenticated;

grant UPDATE (version, currency_code, ends_at, created_at, description, id, kind, merchant_id, name, points_per_currency, rules, stamp_goal, starts_at, state, updated_at) on table public.loyalty_programs to authenticated;

grant SELECT (role, is_active, user_id, permissions, invited_by, created_at, merchant_id) on table public.merchant_members to authenticated;

grant INSERT (email, status, logo_path, address, cover_path, category, country_code, created_at, updated_at, description, id, name, city, owner_user_id, phone, timezone, slug) on table public.merchants to authenticated;

grant SELECT (created_at, address, city, country_code, logo_path, name, category, slug, owner_user_id, status, updated_at, id, email, description, cover_path, phone, timezone) on table public.merchants to authenticated;

grant UPDATE (cover_path, timezone, logo_path, name, phone, city, email, status, address, category, description) on table public.merchants to authenticated;

grant SELECT (created_at, user_id) on table public.platform_admins to authenticated;

grant SELECT (preferred_locale, id, avatar_path, full_name, phone_e164, updated_at, created_at) on table public.profiles to authenticated;

grant UPDATE (phone_e164, updated_at, full_name, created_at, preferred_locale, avatar_path, id) on table public.profiles to authenticated;

grant INSERT (stock_quantity, image_path, description, points_cost, merchant_id, is_active, title, program_id, stamps_cost, id, created_at) on table public.rewards to authenticated;

grant SELECT (created_at, id, description, merchant_id, points_cost, program_id, stamps_cost, stock_quantity, title, image_path, is_active) on table public.rewards to authenticated;

grant UPDATE (stamps_cost, program_id, points_cost, is_active, image_path, merchant_id, description, created_at, id, title, stock_quantity) on table public.rewards to authenticated;

grant usage, select on all sequences in schema public to authenticated;

revoke all on function private.bootstrap_merchant_owner() from public, anon, authenticated;

revoke all on function private.bump_program_version() from public, anon, authenticated;

revoke all on function private.can_confirm_redeem(p_merchant_id uuid) from public, anon, authenticated;

revoke all on function private.can_issue_earn(p_merchant_id uuid) from public, anon, authenticated;

revoke all on function private.can_manage_merchant(p_merchant_id uuid) from public, anon, authenticated;

revoke all on function private.guard_merchant_status() from public, anon, authenticated;

revoke all on function private.is_merchant_member(p_merchant_id uuid) from public, anon, authenticated;

revoke all on function private.is_platform_admin() from public, anon, authenticated;

revoke all on function private.on_auth_user_created() from public, anon, authenticated;

revoke all on function private.prevent_audit_mutation() from public, anon, authenticated;

revoke all on function private.prevent_ledger_mutation() from public, anon, authenticated;

revoke all on function private.touch_updated_at() from public, anon, authenticated;

revoke all on function public.accept_merchant_invite(p_code text) from public, anon, authenticated;

revoke all on function public.confirm_earn_code(p_code text, p_purchase_amount numeric) from public, anon, authenticated;

revoke all on function public.confirm_redeem_code(p_code text) from public, anon, authenticated;

revoke all on function public.create_customer_checkin_code(p_program_id uuid) from public, anon, authenticated;

revoke all on function public.create_merchant_invite(p_merchant_id uuid, p_phone_e164 text, p_permissions text[]) from public, anon, authenticated;

revoke all on function public.create_redeem_code(p_account_id uuid, p_reward_id uuid) from public, anon, authenticated;

revoke all on function public.join_loyalty_program(p_program_id uuid) from public, anon, authenticated;

revoke all on function public.list_merchant_members(p_merchant_id uuid) from public, anon, authenticated;

revoke all on function public.set_merchant_member(p_merchant_id uuid, p_user_id uuid, p_permissions text[], p_active boolean) from public, anon, authenticated;









grant execute on function public.accept_merchant_invite(p_code text) to authenticated;

grant execute on function public.confirm_earn_code(p_code text, p_purchase_amount numeric) to authenticated;

grant execute on function public.confirm_redeem_code(p_code text) to authenticated;

grant execute on function public.create_customer_checkin_code(p_program_id uuid) to authenticated;

grant execute on function public.create_merchant_invite(p_merchant_id uuid, p_phone_e164 text, p_permissions text[]) to authenticated;

grant execute on function public.create_redeem_code(p_account_id uuid, p_reward_id uuid) to authenticated;

grant execute on function public.join_loyalty_program(p_program_id uuid) to authenticated;

grant execute on function public.list_merchant_members(p_merchant_id uuid) to authenticated;

grant execute on function public.set_merchant_member(p_merchant_id uuid, p_user_id uuid, p_permissions text[], p_active boolean) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values ('merchant-branding','merchant-branding',true,5242880,array['image/jpeg','image/png','image/webp','image/avif']) on conflict(id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values ('reward-media','reward-media',true,5242880,array['image/jpeg','image/png','image/webp','image/avif']) on conflict(id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create index if not exists merchant_invites_created_by_idx on public.merchant_invites(created_by);
create index if not exists merchant_invites_accepted_by_idx on public.merchant_invites(accepted_by);


-- Internal helper and trigger functions are never callable through client roles.
revoke all on all functions in schema private from public, anon, authenticated;
