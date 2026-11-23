alter table private.wathaq_qr_codes add column if not exists serial integer;
update private.wathaq_qr_codes c set serial=x.rn from (select id,row_number() over(partition by batch_id order by created_at,id)::integer rn from private.wathaq_qr_codes) x where c.id=x.id and c.serial is null;
alter table private.wathaq_qr_codes alter column serial set not null;
create unique index if not exists wathaq_qr_codes_batch_serial_uidx on private.wathaq_qr_codes(batch_id,serial);
create or replace function private.admin_create_qr_batch(p_merchant_id uuid,p_program_id uuid,p_quantity integer,p_amount integer,p_expires_at timestamptz) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=(select auth.uid()); v_program public.loyalty_programs%rowtype; v_merchant public.merchants%rowtype; v_batch uuid; v_key text; v_code text; v_digest text; v_codes jsonb:='[]'::jsonb; i integer;
begin
 if v_user is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not(private.is_platform_admin() or private.has_platform_permission('loyalty.qr.manage')) then raise exception 'not authorized' using errcode='42501'; end if;
 if p_quantity is null or p_quantity not between 1 and 1000 then raise exception 'quantity must be 1..1000'; end if;
 if p_amount is null or p_amount not between 1 and 1000000 then raise exception 'amount must be 1..1000000'; end if;
 if p_expires_at is null or p_expires_at<=now() or p_expires_at>now()+interval '365 days' then raise exception 'expiry must be within the next 365 days'; end if;
 select * into v_merchant from public.merchants where id=p_merchant_id for share;
 if not found or v_merchant.status<>'active' then raise exception 'merchant unavailable'; end if;
 select * into v_program from public.loyalty_programs where id=p_program_id and merchant_id=p_merchant_id for share;
 if not found or v_program.state<>'active' or (v_program.starts_at is not null and v_program.starts_at>now()) or (v_program.ends_at is not null and v_program.ends_at<=now()) then raise exception 'program unavailable'; end if;
 select key_hex into v_key from private.wathaq_qr_print_key where singleton=true;
 if v_key is null then raise exception 'QR encryption key unavailable'; end if;
 insert into private.wathaq_qr_batches(merchant_id,program_id,created_by,reward_kind,quantity,amount,expires_at) values(p_merchant_id,p_program_id,v_user,v_program.kind,p_quantity,p_amount,p_expires_at) returning id into v_batch;
 for i in 1..p_quantity loop
  loop
   v_code:=upper(encode(extensions.gen_random_bytes(16),'hex')); v_digest:=encode(extensions.digest(v_code,'sha256'),'hex');
   exit when not exists(select 1 from private.wathaq_qr_codes where token_digest=v_digest) and not exists(select 1 from public.loyalty_tokens where token_digest=v_digest);
  end loop;
  insert into private.wathaq_qr_codes(batch_id,serial,token_digest,code_ciphertext) values(v_batch,i,v_digest,extensions.pgp_sym_encrypt(v_code,v_key,'cipher-algo=aes256,compress-algo=0'));
  v_codes:=v_codes||jsonb_build_array(jsonb_build_object('code',v_code,'serial',i));
 end loop;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details) values(v_user,p_merchant_id,'loyalty.qr_batch_created','qr_batch',v_batch::text,jsonb_build_object('program_id',p_program_id,'kind',v_program.kind,'quantity',p_quantity,'amount_per_code',p_amount,'expires_at',p_expires_at));
 return jsonb_build_object('ok',true,'batch_id',v_batch,'quantity',p_quantity,'kind',v_program.kind,'amount',p_amount,'expires_at',p_expires_at,'codes',v_codes);
end; $$;
create or replace function private.admin_get_qr_batch_print_data(p_batch_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_batch private.wathaq_qr_batches%rowtype; v_key text; v_codes jsonb;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not(private.is_platform_admin() or private.has_platform_permission('loyalty.qr.manage')) then raise exception 'not authorized' using errcode='42501'; end if;
 select * into v_batch from private.wathaq_qr_batches where id=p_batch_id; if not found then raise exception 'batch not found'; end if;
 select key_hex into v_key from private.wathaq_qr_print_key where singleton=true;
 select coalesce(jsonb_agg(jsonb_build_object('serial',c.serial,'code',extensions.pgp_sym_decrypt(c.code_ciphertext,v_key),'state',c.state) order by c.serial),'[]'::jsonb) into v_codes from private.wathaq_qr_codes c where c.batch_id=p_batch_id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details) values((select auth.uid()),v_batch.merchant_id,'loyalty.qr_batch_reprinted','qr_batch',p_batch_id::text,jsonb_build_object('quantity',v_batch.quantity));
 return jsonb_build_object('batch_id',v_batch.id,'merchant_id',v_batch.merchant_id,'program_id',v_batch.program_id,'kind',v_batch.reward_kind,'amount',v_batch.amount,'expires_at',v_batch.expires_at,'state',v_batch.state,'codes',v_codes);
end; $$;
