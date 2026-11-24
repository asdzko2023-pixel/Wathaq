-- Allow platform admins to activate/deactivate merchant staff memberships.
-- The merchant owner cannot be changed through this endpoint. Every mutation is audited.

create or replace function private.admin_set_merchant_member_active(
  p_merchant_id uuid,
  p_user_id uuid,
  p_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_member public.merchant_members%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_platform_admin() then
    raise exception 'platform administrator required' using errcode = '42501';
  end if;
  if p_merchant_id is null or p_user_id is null or p_active is null then
    raise exception 'invalid input' using errcode = '22023';
  end if;

  select * into v_member
    from public.merchant_members
   where merchant_id = p_merchant_id and user_id = p_user_id
   for update;

  if not found or v_member.role = 'owner' then
    return jsonb_build_object('ok', false, 'error', 'member_unavailable');
  end if;

  if v_member.is_active = p_active then
    return jsonb_build_object('ok', true, 'changed', false);
  end if;

  update public.merchant_members
     set is_active = p_active
   where merchant_id = p_merchant_id and user_id = p_user_id;

  insert into public.audit_events(actor_user_id, merchant_id, action, entity_type, entity_id, details)
  values (
    (select auth.uid()),
    p_merchant_id,
    'platform.merchant_member_status_changed',
    'merchant_member',
    p_user_id::text,
    jsonb_build_object('active', p_active, 'previous_active', v_member.is_active, 'role', v_member.role)
  );

  return jsonb_build_object('ok', true, 'changed', true);
end;
$function$;

revoke all on function private.admin_set_merchant_member_active(uuid, uuid, boolean) from public;
revoke all on function private.admin_set_merchant_member_active(uuid, uuid, boolean) from anon;
grant execute on function private.admin_set_merchant_member_active(uuid, uuid, boolean) to authenticated;

create or replace function public.admin_set_merchant_member_active(
  p_merchant_id uuid,
  p_user_id uuid,
  p_active boolean
)
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
  select private.admin_set_merchant_member_active($1, $2, $3);
$function$;

revoke all on function public.admin_set_merchant_member_active(uuid, uuid, boolean) from public;
revoke all on function public.admin_set_merchant_member_active(uuid, uuid, boolean) from anon;
grant execute on function public.admin_set_merchant_member_active(uuid, uuid, boolean) to authenticated;
