-- Apply permission-scoped access to existing administrative RPCs.
-- The Super Admin predicate remains unchanged; operators receive only explicit capabilities.
do $migration$
declare
 v_item record;
 v_definition text;
 v_replacement text;
begin
 for v_item in
   select * from (values
    ('private','admin_list_user_profiles','p_search text, p_limit integer, p_offset integer','users.read'),
    ('private','admin_list_merchant_staff','p_search text, p_limit integer, p_offset integer','staff.read'),
    ('private','admin_create_merchant_invite','p_merchant_id uuid, p_phone_e164 text, p_permissions text[]','staff.invites.manage'),
    ('private','admin_list_merchant_invites','p_merchant_id uuid, p_limit integer','staff.invites.manage'),
    ('private','admin_revoke_merchant_invite','p_invite_id uuid','staff.invites.manage'),
    ('private','admin_set_merchant_member_active','p_merchant_id uuid, p_user_id uuid, p_active boolean','staff.status.manage'),
    ('private','admin_list_rewards','p_search text, p_limit integer','loyalty.read'),
    ('private','admin_set_reward_active','p_reward_id uuid, p_active boolean','loyalty.rewards.manage'),
    ('private','admin_set_loyalty_program_state','p_program_id uuid, p_state public.program_state','loyalty.programs.manage'),
    ('public','admin_set_merchant_status','p_merchant_id uuid, p_status public.merchant_state','merchants.status.manage')
   ) as x(schema_name,function_name,identity_args,permission_key)
 loop
   select pg_get_functiondef(p.oid) into v_definition
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname=v_item.schema_name and p.proname=v_item.function_name
     and pg_get_function_identity_arguments(p.oid)=v_item.identity_args;
   if v_definition is null then
     raise exception 'Missing expected function %.%(%)',v_item.schema_name,v_item.function_name,v_item.identity_args;
   end if;
   v_replacement:=replace(v_definition,
     'if not private.is_platform_admin() then',
     'if not private.has_platform_permission('''||v_item.permission_key||''') then');
   if v_replacement=v_definition then
     raise exception 'Expected authorization guard not found in %.%',v_item.schema_name,v_item.function_name;
   end if;
   execute v_replacement;
 end loop;
end;
$migration$;

create or replace function private.admin_list_merchants(p_search text default null,p_limit integer default 200)
returns table(id uuid,name text,slug text,status public.merchant_state,category text,city text,created_at timestamptz)
language plpgsql security definer set search_path=''
as $function$
declare v_search text:=nullif(left(btrim(coalesce(p_search,'')),100),''); v_limit integer:=least(greatest(coalesce(p_limit,200),1),200);
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.has_platform_permission('merchants.read') then raise exception 'permission denied' using errcode='42501'; end if;
 return query select m.id,m.name,m.slug,m.status,m.category,m.city,m.created_at
 from public.merchants m
 where v_search is null or m.name ilike '%'||v_search||'%' or m.slug ilike '%'||v_search||'%' or coalesce(m.city,'') ilike '%'||v_search||'%' or coalesce(m.category,'') ilike '%'||v_search||'%'
 order by m.created_at desc limit v_limit;
end;
$function$;

create or replace function public.admin_list_merchants(p_search text default null,p_limit integer default 200)
returns table(id uuid,name text,slug text,status public.merchant_state,category text,city text,created_at timestamptz)
language sql security invoker set search_path=''
as $function$ select * from private.admin_list_merchants($1,$2); $function$;
revoke all on function private.admin_list_merchants(text,integer) from public,anon;
grant execute on function private.admin_list_merchants(text,integer) to authenticated;
revoke all on function public.admin_list_merchants(text,integer) from public,anon;
grant execute on function public.admin_list_merchants(text,integer) to authenticated;

create or replace function private.admin_list_platform_audit(p_limit integer default 100)
returns table(id bigint,action text,entity_type text,entity_id text,merchant_id uuid,created_at timestamptz,details jsonb)
language plpgsql security definer set search_path=''
as $function$
declare v_limit integer:=least(greatest(coalesce(p_limit,100),1),200);
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.has_platform_permission('audit.read') then raise exception 'permission denied' using errcode='42501'; end if;
 return query select a.id,a.action,a.entity_type,a.entity_id,a.merchant_id,a.created_at,
   (coalesce(a.details,'{}'::jsonb)-'phone_e164'-'email'-'invite_code') as details
 from public.audit_events a order by a.created_at desc limit v_limit;
end;
$function$;
create or replace function public.admin_list_platform_audit(p_limit integer default 100)
returns table(id bigint,action text,entity_type text,entity_id text,merchant_id uuid,created_at timestamptz,details jsonb)
language sql security invoker set search_path=''
as $function$ select * from private.admin_list_platform_audit($1); $function$;
revoke all on function private.admin_list_platform_audit(integer) from public,anon;
grant execute on function private.admin_list_platform_audit(integer) to authenticated;
revoke all on function public.admin_list_platform_audit(integer) from public,anon;
grant execute on function public.admin_list_platform_audit(integer) to authenticated;

create or replace function private.admin_get_loyalty_dashboard()
returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_programs jsonb; v_rewards jsonb; v_accounts jsonb; v_ledger jsonb;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.has_platform_permission('loyalty.read') then raise exception 'permission denied' using errcode='42501'; end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_programs
 from (select id,merchant_id,name,kind,state,created_at from public.loyalty_programs order by created_at desc limit 100) x;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_accounts
 from (select id,points_balance,stamps_balance,joined_at,joined_at as created_at from public.loyalty_accounts order by joined_at desc limit 8) x;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_ledger
 from (select id,kind,points_delta,stamps_delta,created_at,reference from public.loyalty_ledger order by created_at desc limit 12) x;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_rewards
 from (select r.id as reward_id,r.merchant_id,m.name as merchant_name,r.program_id,p.name as program_name,r.title,r.description,r.points_cost,r.stamps_cost,r.stock_quantity,r.is_active,r.created_at
       from public.rewards r join public.merchants m on m.id=r.merchant_id join public.loyalty_programs p on p.id=r.program_id
       order by r.created_at desc limit 200) x;
 return jsonb_build_object('programs',v_programs,'accounts',v_accounts,'ledger',v_ledger,'rewards',v_rewards);
end;
$function$;
create or replace function public.admin_get_loyalty_dashboard()
returns jsonb language sql security invoker set search_path=''
as $function$ select private.admin_get_loyalty_dashboard(); $function$;
revoke all on function private.admin_get_loyalty_dashboard() from public,anon;
grant execute on function private.admin_get_loyalty_dashboard() to authenticated;
revoke all on function public.admin_get_loyalty_dashboard() from public,anon;
grant execute on function public.admin_get_loyalty_dashboard() to authenticated;

create or replace function private.admin_get_platform_stats()
returns jsonb
language plpgsql security definer set search_path=''
as $function$
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not (private.has_platform_permission('merchants.read') or private.has_platform_permission('loyalty.read') or private.has_platform_permission('audit.read')) then raise exception 'permission denied' using errcode='42501'; end if;
 return jsonb_build_object(
  'merchants',(select count(*) from public.merchants),
  'loyalty_accounts',(select count(*) from public.loyalty_accounts),
  'loyalty_ledger',(select count(*) from public.loyalty_ledger),
  'audit_events',(select count(*) from public.audit_events)
 );
end;
$function$;
create or replace function public.admin_get_platform_stats()
returns jsonb language sql security invoker set search_path=''
as $function$ select private.admin_get_platform_stats(); $function$;
revoke all on function private.admin_get_platform_stats() from public,anon;
grant execute on function private.admin_get_platform_stats() to authenticated;
revoke all on function public.admin_get_platform_stats() from public,anon;
grant execute on function public.admin_get_platform_stats() to authenticated;
