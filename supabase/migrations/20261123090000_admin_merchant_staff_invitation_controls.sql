-- Platform-admin merchant staff invitations.
-- Invitation codes are returned once, stored only as SHA-256 digests, and expire after 48 hours.
create or replace function private.admin_create_merchant_invite(p_merchant_id uuid,p_phone_e164 text,p_permissions text[] default array['issue_earn']::text[])
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare v_code text; v_id uuid; v_name text;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.is_platform_admin() then raise exception 'platform administrator required' using errcode='42501'; end if;
 if p_merchant_id is null or p_phone_e164 is null or p_phone_e164 !~ '^\+[1-9][0-9]{7,14}$'
    or p_permissions is null or cardinality(p_permissions)=0
    or not (p_permissions <@ array['issue_earn','confirm_redeem','view_analytics']::text[]) then
   raise exception 'invalid invitation input' using errcode='22023';
 end if;
 select name into v_name from public.merchants where id=p_merchant_id and status='active';
 if not found then return jsonb_build_object('ok',false,'error','active_merchant_required'); end if;
 v_code:=upper(substr(encode(extensions.gen_random_bytes(16),'hex'),1,16));
 insert into public.merchant_invites(merchant_id,phone_e164,permissions,invite_digest,created_by,expires_at)
 values(p_merchant_id,p_phone_e164,p_permissions,encode(extensions.digest(v_code,'sha256'),'hex'),(select auth.uid()),now()+interval '48 hours')
 returning id into v_id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details)
 values((select auth.uid()),p_merchant_id,'platform.merchant_staff_invited','merchant_invite',v_id::text,
 jsonb_build_object('phone_e164',p_phone_e164,'permissions',p_permissions,'expires_in_hours',48));
 return jsonb_build_object('ok',true,'invite_id',v_id,'merchant_name',v_name,'code',v_code,'expires_in_hours',48);
end;$function$;

create or replace function private.admin_list_merchant_invites(p_merchant_id uuid default null,p_limit integer default 100)
returns table(invite_id uuid,merchant_id uuid,merchant_name text,phone_e164 text,permissions text[],created_at timestamptz,expires_at timestamptz,accepted_at timestamptz,revoked_at timestamptz,created_by uuid)
language plpgsql security definer set search_path = ''
as $function$
declare v_limit integer:=least(greatest(coalesce(p_limit,100),1),200);
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.is_platform_admin() then raise exception 'platform administrator required' using errcode='42501'; end if;
 return query select i.id,i.merchant_id,m.name,i.phone_e164,i.permissions,i.created_at,i.expires_at,i.accepted_at,i.revoked_at,i.created_by
 from public.merchant_invites i join public.merchants m on m.id=i.merchant_id
 where p_merchant_id is null or i.merchant_id=p_merchant_id order by i.created_at desc limit v_limit;
end;$function$;

create or replace function private.admin_revoke_merchant_invite(p_invite_id uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare v_invite public.merchant_invites%rowtype;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.is_platform_admin() then raise exception 'platform administrator required' using errcode='42501'; end if;
 if p_invite_id is null then raise exception 'invite id required' using errcode='22023'; end if;
 select * into v_invite from public.merchant_invites where id=p_invite_id for update;
 if not found or v_invite.accepted_at is not null or v_invite.revoked_at is not null or v_invite.expires_at<=now()
 then return jsonb_build_object('ok',false,'error','invite_unavailable'); end if;
 update public.merchant_invites set revoked_at=now() where id=p_invite_id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details)
 values((select auth.uid()),v_invite.merchant_id,'platform.merchant_invite_revoked','merchant_invite',p_invite_id::text,jsonb_build_object('phone_e164',v_invite.phone_e164));
 return jsonb_build_object('ok',true);
end;$function$;

revoke all on function private.admin_create_merchant_invite(uuid,text,text[]) from public,anon;
revoke all on function private.admin_list_merchant_invites(uuid,integer) from public,anon;
revoke all on function private.admin_revoke_merchant_invite(uuid) from public,anon;
grant execute on function private.admin_create_merchant_invite(uuid,text,text[]) to authenticated;
grant execute on function private.admin_list_merchant_invites(uuid,integer) to authenticated;
grant execute on function private.admin_revoke_merchant_invite(uuid) to authenticated;

create or replace function public.admin_create_merchant_invite(p_merchant_id uuid,p_phone_e164 text,p_permissions text[] default array['issue_earn']::text[])
returns jsonb language sql security invoker set search_path = '' as $function$ select private.admin_create_merchant_invite($1,$2,$3); $function$;
create or replace function public.admin_list_merchant_invites(p_merchant_id uuid default null,p_limit integer default 100)
returns table(invite_id uuid,merchant_id uuid,merchant_name text,phone_e164 text,permissions text[],created_at timestamptz,expires_at timestamptz,accepted_at timestamptz,revoked_at timestamptz,created_by uuid)
language sql security invoker set search_path = '' as $function$ select * from private.admin_list_merchant_invites($1,$2); $function$;
create or replace function public.admin_revoke_merchant_invite(p_invite_id uuid)
returns jsonb language sql security invoker set search_path = '' as $function$ select private.admin_revoke_merchant_invite($1); $function$;
revoke all on function public.admin_create_merchant_invite(uuid,text,text[]) from public,anon;
revoke all on function public.admin_list_merchant_invites(uuid,integer) from public,anon;
revoke all on function public.admin_revoke_merchant_invite(uuid) from public,anon;
grant execute on function public.admin_create_merchant_invite(uuid,text,text[]) to authenticated;
grant execute on function public.admin_list_merchant_invites(uuid,integer) to authenticated;
grant execute on function public.admin_revoke_merchant_invite(uuid) to authenticated;
