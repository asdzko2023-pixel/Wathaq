create or replace function private.claim_admin_qr_code(p_code text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
 v_user uuid:=(select auth.uid()); v_code_id uuid; v_batch_id uuid;
 v_code private.wathaq_qr_codes%rowtype; v_batch private.wathaq_qr_batches%rowtype;
 v_program public.loyalty_programs%rowtype; v_merchant public.merchants%rowtype;
 v_account public.loyalty_accounts%rowtype; v_points bigint:=0; v_stamps integer:=0;
begin
 if v_user is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_code is null or p_code !~ '^[A-F0-9]{32}$' then return jsonb_build_object('ok',false,'error','invalid_code'); end if;
 -- Batch first, code second: this is the same lock order used by batch revocation.
 select id,batch_id into v_code_id,v_batch_id from private.wathaq_qr_codes
 where token_digest=encode(extensions.digest(upper(p_code),'sha256'),'hex');
 if not found then return jsonb_build_object('ok',false,'error','code_unavailable'); end if;
 select * into v_batch from private.wathaq_qr_batches where id=v_batch_id for share;
 if not found then return jsonb_build_object('ok',false,'error','batch_unavailable'); end if;
 select * into v_code from private.wathaq_qr_codes where id=v_code_id for update;
 if not found then return jsonb_build_object('ok',false,'error','code_unavailable'); end if;
 if v_code.state<>'issued' then return jsonb_build_object('ok',false,'error','code_used_or_revoked'); end if;
 if v_batch.state<>'active' then return jsonb_build_object('ok',false,'error','batch_revoked'); end if;
 if v_batch.expires_at<=now() then update private.wathaq_qr_codes set state='expired' where id=v_code.id; return jsonb_build_object('ok',false,'error','code_expired'); end if;
 select * into v_merchant from public.merchants where id=v_batch.merchant_id;
 if not found or v_merchant.status<>'active' then return jsonb_build_object('ok',false,'error','merchant_unavailable'); end if;
 select * into v_program from public.loyalty_programs where id=v_batch.program_id;
 if not found or v_program.state<>'active' or (v_program.starts_at is not null and v_program.starts_at>now()) or (v_program.ends_at is not null and v_program.ends_at<=now()) then return jsonb_build_object('ok',false,'error','program_unavailable'); end if;
 if v_program.kind<>v_batch.reward_kind then return jsonb_build_object('ok',false,'error','program_kind_mismatch'); end if;
 insert into public.loyalty_accounts(customer_id,merchant_id,program_id) values(v_user,v_batch.merchant_id,v_batch.program_id) on conflict(customer_id,program_id) do nothing;
 select * into v_account from public.loyalty_accounts where customer_id=v_user and program_id=v_batch.program_id for update;
 if v_account.id is null then raise exception 'loyalty account could not be created'; end if;
 if v_batch.reward_kind='points' then
  v_points:=v_batch.amount;
  update public.loyalty_accounts set points_balance=points_balance+v_points,lifetime_points=lifetime_points+v_points,last_activity_at=now() where id=v_account.id returning * into v_account;
 else
  v_stamps:=v_batch.amount;
  update public.loyalty_accounts set stamps_balance=stamps_balance+v_stamps,lifetime_stamps=lifetime_stamps+v_stamps,last_activity_at=now() where id=v_account.id returning * into v_account;
 end if;
 insert into public.loyalty_ledger(account_id,customer_id,merchant_id,program_id,kind,points_delta,stamps_delta,points_after,stamps_after,reference,idempotency_key,program_version,actor_user_id,metadata)
 values(v_account.id,v_user,v_batch.merchant_id,v_batch.program_id,'earn',v_points,v_stamps,v_account.points_balance,v_account.stamps_balance,'admin_qr_batch','admin_qr:'||v_code.id::text,v_program.version,v_user,jsonb_build_object('qr_batch_id',v_batch.id,'qr_code_id',v_code.id));
 update private.wathaq_qr_codes set state='consumed',consumed_by=v_user,consumed_at=now() where id=v_code.id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details)
 values(v_user,v_batch.merchant_id,'loyalty.qr_code_claimed','qr_code',v_code.id::text,jsonb_build_object('batch_id',v_batch.id,'points_added',v_points,'stamps_added',v_stamps));
 return jsonb_build_object('ok',true,'points_added',v_points,'stamps_added',v_stamps,'points_balance',v_account.points_balance,'stamps_balance',v_account.stamps_balance);
end; $$;
