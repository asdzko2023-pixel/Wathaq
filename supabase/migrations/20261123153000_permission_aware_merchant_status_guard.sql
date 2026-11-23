create or replace function private.guard_merchant_status()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
 if new.status is distinct from old.status
    and not private.has_platform_permission('merchants.status.manage') then
   raise exception 'merchant status permission required' using errcode='42501';
 end if;
 if new.status is distinct from old.status then
   insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details)
   values((select auth.uid()),old.id,'merchant.status_changed','merchant',old.id::text,
          jsonb_build_object('from',old.status,'to',new.status));
 end if;
 return new;
end;
$function$;
