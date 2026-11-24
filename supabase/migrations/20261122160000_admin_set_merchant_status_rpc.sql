-- Narrow, server-authorized merchant status transition for the platform console.
-- Do not grant broad UPDATE on public.merchants to browser roles.

create or replace function public.admin_set_merchant_status(
  p_merchant_id uuid,
  p_status public.merchant_state
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_id uuid;
  v_status public.merchant_state;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  if not private.is_platform_admin() then
    raise exception 'platform administrator required' using errcode = '42501';
  end if;

  if p_merchant_id is null or p_status is null then
    raise exception 'merchant and status are required' using errcode = '22004';
  end if;

  update public.merchants
     set status = p_status
   where id = p_merchant_id
   returning id, status into v_id, v_status;

  if not found then
    raise exception 'merchant not found' using errcode = 'P0002';
  end if;

  -- merchants_status_guard remains responsible for inserting the audit event.
  return jsonb_build_object('ok', true, 'merchant_id', v_id, 'status', v_status);
end;
$function$;

revoke all on function public.admin_set_merchant_status(uuid, public.merchant_state) from public;
revoke all on function public.admin_set_merchant_status(uuid, public.merchant_state) from anon;
grant execute on function public.admin_set_merchant_status(uuid, public.merchant_state) to authenticated;
