create or replace function private.admin_get_platform_stats()
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
 v_merchants bigint; v_accounts bigint; v_ledger bigint; v_audit bigint;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not (private.has_platform_permission('merchants.read') or private.has_platform_permission('loyalty.read') or private.has_platform_permission('audit.read')) then raise exception 'permission denied' using errcode='42501'; end if;
 if private.has_platform_permission('merchants.read') then select count(*) into v_merchants from public.merchants; end if;
 if private.has_platform_permission('loyalty.read') then
   select count(*) into v_accounts from public.loyalty_accounts;
   select count(*) into v_ledger from public.loyalty_ledger;
 end if;
 if private.has_platform_permission('audit.read') then select count(*) into v_audit from public.audit_events; end if;
 return jsonb_build_object('merchants',v_merchants,'loyalty_accounts',v_accounts,'loyalty_ledger',v_ledger,'audit_events',v_audit);
end;
$function$;

create or replace function private.admin_get_my_permissions()
returns text[]
language plpgsql security definer set search_path=''
as $function$
declare v_permissions text[];
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if private.is_platform_admin() then
   return array['users.read','merchants.read','merchants.status.manage','staff.read','staff.status.manage','staff.invites.manage','loyalty.read','loyalty.programs.manage','loyalty.rewards.manage','audit.read','analytics.read']::text[];
 end if;
 select coalesce(array_agg(distinct rp.permission_key order by rp.permission_key),array[]::text[])
 into v_permissions
 from public.platform_admin_memberships m
 join public.platform_admin_role_permissions rp on rp.role_key=m.role_key
 where m.user_id=(select auth.uid()) and m.is_active;
 return coalesce(v_permissions,array[]::text[]);
end;
$function$;
create or replace function public.admin_get_my_permissions()
returns text[] language sql security invoker set search_path=''
as $function$ select private.admin_get_my_permissions(); $function$;
revoke all on function private.admin_get_my_permissions() from public,anon;
grant execute on function private.admin_get_my_permissions() to authenticated;
revoke all on function public.admin_get_my_permissions() from public,anon;
grant execute on function public.admin_get_my_permissions() to authenticated;
