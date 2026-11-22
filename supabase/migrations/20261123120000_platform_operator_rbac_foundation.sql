-- WATHAQ platform RBAC foundation.
-- Super administrators remain exclusively in public.platform_admins.
-- Operator memberships never make private.is_platform_admin() true.
create table if not exists public.platform_admin_roles (
  role_key text primary key,
  name text not null,
  description text not null,
  is_system boolean not null default true,
  created_at timestamptz not null default now(),
  constraint platform_admin_roles_key_format check (role_key ~ '^[a-z][a-z0-9_]{2,40}$')
);

create table if not exists public.platform_admin_role_permissions (
  role_key text not null references public.platform_admin_roles(role_key) on delete cascade,
  permission_key text not null,
  created_at timestamptz not null default now(),
  primary key (role_key, permission_key),
  constraint platform_admin_permission_format check (permission_key ~ '^[a-z][a-z0-9_.]{2,70}$')
);

create table if not exists public.platform_admin_memberships (
  user_id uuid primary key references auth.users(id) on delete restrict,
  role_key text not null references public.platform_admin_roles(role_key) on delete restrict,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

create index if not exists platform_admin_memberships_role_active_idx
  on public.platform_admin_memberships(role_key, is_active);

alter table public.platform_admin_roles enable row level security;
alter table public.platform_admin_role_permissions enable row level security;
alter table public.platform_admin_memberships enable row level security;

revoke all on public.platform_admin_roles, public.platform_admin_role_permissions, public.platform_admin_memberships from anon, authenticated;
grant select, insert, update, delete on public.platform_admin_roles, public.platform_admin_role_permissions, public.platform_admin_memberships to service_role;

insert into public.platform_admin_roles(role_key,name,description) values
 ('support_viewer','دعم العملاء','قراءة بيانات المستخدمين والمتاجر والموظفين والولاء وسجل التدقيق'),
 ('merchant_operator','مشغّل المتاجر','إدارة حالات المتاجر وعضويات الموظفين والدعوات'),
 ('loyalty_operator','مشغّل الولاء','إدارة حالات برامج الولاء والمكافآت'),
 ('analytics_viewer','محلّل التقارير','عرض التقارير والمؤشرات وسجل التدقيق')
on conflict (role_key) do update set name=excluded.name, description=excluded.description;

insert into public.platform_admin_role_permissions(role_key,permission_key) values
 ('support_viewer','users.read'),('support_viewer','merchants.read'),('support_viewer','staff.read'),('support_viewer','loyalty.read'),('support_viewer','audit.read'),
 ('merchant_operator','merchants.read'),('merchant_operator','merchants.status.manage'),('merchant_operator','staff.read'),('merchant_operator','staff.status.manage'),('merchant_operator','staff.invites.manage'),('merchant_operator','audit.read'),
 ('loyalty_operator','loyalty.read'),('loyalty_operator','loyalty.programs.manage'),('loyalty_operator','loyalty.rewards.manage'),('loyalty_operator','audit.read'),
 ('analytics_viewer','analytics.read'),('analytics_viewer','audit.read')
on conflict do nothing;

create or replace function private.has_platform_permission(p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select case
    when (select auth.uid()) is null or p_permission is null then false
    when private.is_platform_admin() then true
    else exists (
      select 1
      from public.platform_admin_memberships m
      join public.platform_admin_role_permissions rp on rp.role_key=m.role_key
      where m.user_id=(select auth.uid())
        and m.is_active
        and rp.permission_key=p_permission
    )
  end;
$function$;

revoke all on function private.has_platform_permission(text) from public, anon, authenticated;
grant execute on function private.has_platform_permission(text) to authenticated;

create or replace function private.admin_list_platform_roles()
returns table(role_key text,name text,description text,permissions text[])
language plpgsql
security definer
set search_path = ''
as $function$
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.is_platform_admin() then raise exception 'super administrator required' using errcode='42501'; end if;
 return query
 select r.role_key,r.name,r.description,coalesce(array_agg(p.permission_key order by p.permission_key) filter(where p.permission_key is not null),array[]::text[])
 from public.platform_admin_roles r
 left join public.platform_admin_role_permissions p on p.role_key=r.role_key
 group by r.role_key,r.name,r.description order by r.role_key;
end;
$function$;

create or replace function private.admin_list_platform_operators()
returns table(user_id uuid,full_name text,role_key text,role_name text,is_active boolean,created_at timestamptz,updated_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $function$
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.is_platform_admin() then raise exception 'super administrator required' using errcode='42501'; end if;
 return query
 select m.user_id,p.full_name,m.role_key,r.name,m.is_active,m.created_at,m.updated_at
 from public.platform_admin_memberships m
 join public.platform_admin_roles r on r.role_key=m.role_key
 left join public.profiles p on p.id=m.user_id
 order by m.created_at desc;
end;
$function$;

create or replace function private.admin_set_platform_operator(
 p_user_id uuid,p_role_key text,p_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_previous public.platform_admin_memberships%rowtype;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.is_platform_admin() then raise exception 'super administrator required' using errcode='42501'; end if;
 if p_user_id is null or p_role_key is null or p_active is null then raise exception 'invalid operator input' using errcode='22023'; end if;
 if p_user_id=(select auth.uid()) then raise exception 'cannot assign or modify your own operator membership' using errcode='42501'; end if;
 if exists(select 1 from public.platform_admins a where a.user_id=p_user_id) then
   raise exception 'super administrators are managed only through platform_admins' using errcode='42501';
 end if;
 if not exists(select 1 from auth.users u where u.id=p_user_id) then
   raise exception 'user not found' using errcode='P0002';
 end if;
 if not exists(select 1 from public.platform_admin_roles r where r.role_key=p_role_key) then
   raise exception 'unknown operator role' using errcode='22023';
 end if;
 select * into v_previous from public.platform_admin_memberships where user_id=p_user_id for update;
 insert into public.platform_admin_memberships(user_id,role_key,is_active,created_by,updated_by)
 values(p_user_id,p_role_key,p_active,(select auth.uid()),(select auth.uid()))
 on conflict(user_id) do update set role_key=excluded.role_key,is_active=excluded.is_active,updated_at=now(),updated_by=(select auth.uid());
 insert into public.audit_events(actor_user_id,action,entity_type,entity_id,details)
 values((select auth.uid()),'platform.operator_membership_changed','platform_operator',p_user_id::text,
   jsonb_build_object('previous_role',v_previous.role_key,'previous_active',v_previous.is_active,'role',p_role_key,'active',p_active));
 return jsonb_build_object('ok',true,'user_id',p_user_id,'role_key',p_role_key,'is_active',p_active);
end;
$function$;

create or replace function private.admin_disable_platform_operator(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_membership public.platform_admin_memberships%rowtype;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.is_platform_admin() then raise exception 'super administrator required' using errcode='42501'; end if;
 if p_user_id is null or p_user_id=(select auth.uid()) then raise exception 'invalid operator target' using errcode='22023'; end if;
 select * into v_membership from public.platform_admin_memberships where user_id=p_user_id for update;
 if not found then return jsonb_build_object('ok',false,'error','operator_not_found'); end if;
 if not v_membership.is_active then return jsonb_build_object('ok',true,'changed',false); end if;
 update public.platform_admin_memberships set is_active=false,updated_at=now(),updated_by=(select auth.uid()) where user_id=p_user_id;
 insert into public.audit_events(actor_user_id,action,entity_type,entity_id,details)
 values((select auth.uid()),'platform.operator_disabled','platform_operator',p_user_id::text,
   jsonb_build_object('previous_role',v_membership.role_key));
 return jsonb_build_object('ok',true,'changed',true);
end;
$function$;

revoke all on function private.admin_list_platform_roles() from public,anon;
revoke all on function private.admin_list_platform_operators() from public,anon;
revoke all on function private.admin_set_platform_operator(uuid,text,boolean) from public,anon;
revoke all on function private.admin_disable_platform_operator(uuid) from public,anon;
grant execute on function private.admin_list_platform_roles() to authenticated;
grant execute on function private.admin_list_platform_operators() to authenticated;
grant execute on function private.admin_set_platform_operator(uuid,text,boolean) to authenticated;
grant execute on function private.admin_disable_platform_operator(uuid) to authenticated;

create or replace function public.admin_list_platform_roles()
returns table(role_key text,name text,description text,permissions text[])
language sql security invoker set search_path = ''
as $function$ select * from private.admin_list_platform_roles(); $function$;
create or replace function public.admin_list_platform_operators()
returns table(user_id uuid,full_name text,role_key text,role_name text,is_active boolean,created_at timestamptz,updated_at timestamptz)
language sql security invoker set search_path = ''
as $function$ select * from private.admin_list_platform_operators(); $function$;
create or replace function public.admin_set_platform_operator(p_user_id uuid,p_role_key text,p_active boolean default true)
returns jsonb language sql security invoker set search_path = ''
as $function$ select private.admin_set_platform_operator($1,$2,$3); $function$;
create or replace function public.admin_disable_platform_operator(p_user_id uuid)
returns jsonb language sql security invoker set search_path = ''
as $function$ select private.admin_disable_platform_operator($1); $function$;

revoke all on function public.admin_list_platform_roles() from public,anon;
revoke all on function public.admin_list_platform_operators() from public,anon;
revoke all on function public.admin_set_platform_operator(uuid,text,boolean) from public,anon;
revoke all on function public.admin_disable_platform_operator(uuid) from public,anon;
grant execute on function public.admin_list_platform_roles() to authenticated;
grant execute on function public.admin_list_platform_operators() to authenticated;
grant execute on function public.admin_set_platform_operator(uuid,text,boolean) to authenticated;
grant execute on function public.admin_disable_platform_operator(uuid) to authenticated;
