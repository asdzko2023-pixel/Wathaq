-- Prevent invite acceptance from overwriting an existing merchant membership.
-- A staff invite must never demote or replace a merchant owner.
create or replace function public.accept_merchant_invite(p_code text)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
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
 on conflict(merchant_id,user_id) do nothing;
 if not found then return jsonb_build_object('ok',false,'error','already_member'); end if;
 update public.merchant_invites set accepted_by=(select auth.uid()),accepted_at=now() where id=v_invite.id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id)
 values((select auth.uid()),v_invite.merchant_id,'merchant.staff_joined','merchant_member',(select auth.uid())::text);
 return jsonb_build_object('ok',true,'merchant_id',v_invite.merchant_id,'permissions',v_invite.permissions);
end;$function$;
revoke all on function public.accept_merchant_invite(text) from public,anon;
grant execute on function public.accept_merchant_invite(text) to authenticated;
