-- WATHAQ secure bulk QR batches: one-time points/stamps coupons.
create schema if not exists private;
create table if not exists private.wathaq_qr_print_key (singleton boolean primary key default true check (singleton),key_hex text not null,created_at timestamptz not null default now());
insert into private.wathaq_qr_print_key(singleton,key_hex) values (true, encode(extensions.gen_random_bytes(32),'hex')) on conflict (singleton) do nothing;
revoke all on private.wathaq_qr_print_key from public, anon, authenticated;
create table if not exists private.wathaq_qr_batches (
 id uuid primary key default gen_random_uuid(),merchant_id uuid not null references public.merchants(id),program_id uuid not null references public.loyalty_programs(id),created_by uuid not null references auth.users(id),
 reward_kind public.loyalty_program_kind not null,quantity integer not null check(quantity between 1 and 1000),amount integer not null check(amount between 1 and 1000000),
 expires_at timestamptz not null,state text not null default 'active' check(state in ('active','revoked')),created_at timestamptz not null default now());
create index if not exists wathaq_qr_batches_created_idx on private.wathaq_qr_batches(created_at desc);
create table if not exists private.wathaq_qr_codes (
 id uuid primary key default gen_random_uuid(),batch_id uuid not null references private.wathaq_qr_batches(id),token_digest text not null unique,code_ciphertext bytea not null,
 state text not null default 'issued' check(state in ('issued','consumed','expired','revoked')),consumed_by uuid references auth.users(id),consumed_at timestamptz,created_at timestamptz not null default now());
create index if not exists wathaq_qr_codes_batch_idx on private.wathaq_qr_codes(batch_id);
revoke all on private.wathaq_qr_batches,private.wathaq_qr_codes from public,anon,authenticated;
insert into public.platform_admin_role_permissions(role_key,permission_key) values('loyalty_operator','loyalty.qr.manage') on conflict do nothing;
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
  insert into private.wathaq_qr_codes(batch_id,token_digest,code_ciphertext) values(v_batch,v_digest,extensions.pgp_sym_encrypt(v_code,v_key,'cipher-algo=aes256,compress-algo=0'));
  v_codes:=v_codes||jsonb_build_array(jsonb_build_object('code',v_code,'serial',i));
 end loop;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details) values(v_user,p_merchant_id,'loyalty.qr_batch_created','qr_batch',v_batch::text,jsonb_build_object('program_id',p_program_id,'kind',v_program.kind,'quantity',p_quantity,'amount_per_code',p_amount,'expires_at',p_expires_at));
 return jsonb_build_object('ok',true,'batch_id',v_batch,'quantity',p_quantity,'kind',v_program.kind,'amount',p_amount,'expires_at',p_expires_at,'codes',v_codes);
end; $$;
create or replace function private.admin_list_qr_batches(p_limit integer default 100) returns table(batch_id uuid,merchant_id uuid,merchant_name text,program_id uuid,program_name text,reward_kind public.loyalty_program_kind,quantity integer,amount integer,expires_at timestamptz,state text,issued_count bigint,consumed_count bigint,created_at timestamptz) language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not(private.is_platform_admin() or private.has_platform_permission('loyalty.qr.manage')) then raise exception 'not authorized' using errcode='42501'; end if;
 return query select b.id,b.merchant_id,m.name,b.program_id,p.name,b.reward_kind,b.quantity,b.amount,b.expires_at,b.state,count(c.id) filter(where c.state='issued'),count(c.id) filter(where c.state='consumed'),b.created_at from private.wathaq_qr_batches b join public.merchants m on m.id=b.merchant_id join public.loyalty_programs p on p.id=b.program_id left join private.wathaq_qr_codes c on c.batch_id=b.id group by b.id,m.name,p.name order by b.created_at desc limit greatest(1,least(coalesce(p_limit,100),200));
end; $$;
create or replace function private.admin_get_qr_batch_print_data(p_batch_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_batch private.wathaq_qr_batches%rowtype; v_key text; v_codes jsonb;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not(private.is_platform_admin() or private.has_platform_permission('loyalty.qr.manage')) then raise exception 'not authorized' using errcode='42501'; end if;
 select * into v_batch from private.wathaq_qr_batches where id=p_batch_id; if not found then raise exception 'batch not found'; end if;
 select key_hex into v_key from private.wathaq_qr_print_key where singleton=true;
 select coalesce(jsonb_agg(jsonb_build_object('serial',row_number,'code',extensions.pgp_sym_decrypt(c.code_ciphertext,v_key),'state',c.state) order by row_number),'[]'::jsonb) into v_codes
 from (select c.*,row_number() over(order by c.created_at,c.id) from private.wathaq_qr_codes c where c.batch_id=p_batch_id) c;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details) values((select auth.uid()),v_batch.merchant_id,'loyalty.qr_batch_reprinted','qr_batch',p_batch_id::text,jsonb_build_object('quantity',v_batch.quantity));
 return jsonb_build_object('batch_id',v_batch.id,'merchant_id',v_batch.merchant_id,'program_id',v_batch.program_id,'kind',v_batch.reward_kind,'amount',v_batch.amount,'expires_at',v_batch.expires_at,'state',v_batch.state,'codes',v_codes);
end; $$;
create or replace function private.admin_revoke_qr_batch(p_batch_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_batch private.wathaq_qr_batches%rowtype; v_count integer;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not(private.is_platform_admin() or private.has_platform_permission('loyalty.qr.manage')) then raise exception 'not authorized' using errcode='42501'; end if;
 update private.wathaq_qr_batches set state='revoked' where id=p_batch_id returning * into v_batch; if not found then raise exception 'batch not found'; end if;
 update private.wathaq_qr_codes set state='revoked' where batch_id=p_batch_id and state='issued'; get diagnostics v_count=row_count;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details) values((select auth.uid()),v_batch.merchant_id,'loyalty.qr_batch_revoked','qr_batch',p_batch_id::text,jsonb_build_object('revoked_codes',v_count));
 return jsonb_build_object('ok',true,'revoked_codes',v_count);
end; $$;
create or replace function public.admin_create_qr_batch(p_merchant_id uuid,p_program_id uuid,p_quantity integer,p_amount integer,p_expires_at timestamptz) returns jsonb language sql security invoker set search_path='' as $$ select private.admin_create_qr_batch($1,$2,$3,$4,$5); $$;
create or replace function public.admin_list_qr_batches(p_limit integer default 100) returns table(batch_id uuid,merchant_id uuid,merchant_name text,program_id uuid,program_name text,reward_kind public.loyalty_program_kind,quantity integer,amount integer,expires_at timestamptz,state text,issued_count bigint,consumed_count bigint,created_at timestamptz) language sql security invoker set search_path='' as $$ select * from private.admin_list_qr_batches($1); $$;
create or replace function public.admin_get_qr_batch_print_data(p_batch_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.admin_get_qr_batch_print_data($1); $$;
create or replace function public.admin_revoke_qr_batch(p_batch_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.admin_revoke_qr_batch($1); $$;
create or replace function public.claim_admin_qr_code(p_code text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=(select auth.uid()); v_code private.wathaq_qr_codes%rowtype; v_batch private.wathaq_qr_batches%rowtype; v_program public.loyalty_programs%rowtype; v_merchant public.merchants%rowtype; v_account public.loyalty_accounts%rowtype; v_points bigint:=0; v_stamps integer:=0;
begin
 if v_user is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_code is null or p_code !~ '^[A-F0-9]{32}$' then return jsonb_build_object('ok',false,'error','invalid_code'); end if;
 select * into v_code from private.wathaq_qr_codes where token_digest=encode(extensions.digest(upper(p_code),'sha256'),'hex') for update;
 if not found then return jsonb_build_object('ok',false,'error','code_unavailable'); end if;
 if v_code.state<>'issued' then return jsonb_build_object('ok',false,'error','code_used_or_revoked'); end if;
 select * into v_batch from private.wathaq_qr_batches where id=v_code.batch_id for update;
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
 if v_batch.reward_kind='points' then v_points:=v_batch.amount; update public.loyalty_accounts set points_balance=points_balance+v_points,lifetime_points=lifetime_points+v_points,last_activity_at=now() where id=v_account.id returning * into v_account;
 else v_stamps:=v_batch.amount; update public.loyalty_accounts set stamps_balance=stamps_balance+v_stamps,lifetime_stamps=lifetime_stamps+v_stamps,last_activity_at=now() where id=v_account.id returning * into v_account; end if;
 insert into public.loyalty_ledger(account_id,customer_id,merchant_id,program_id,kind,points_delta,stamps_delta,points_after,stamps_after,reference,idempotency_key,program_version,actor_user_id,metadata)
 values(v_account.id,v_user,v_batch.merchant_id,v_batch.program_id,'earn',v_points,v_stamps,v_account.points_balance,v_account.stamps_balance,'admin_qr_batch','admin_qr:'||v_code.id::text,v_program.version,v_user,jsonb_build_object('qr_batch_id',v_batch.id,'qr_code_id',v_code.id));
 update private.wathaq_qr_codes set state='consumed',consumed_by=v_user,consumed_at=now() where id=v_code.id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details) values(v_user,v_batch.merchant_id,'loyalty.qr_code_claimed','qr_code',v_code.id::text,jsonb_build_object('batch_id',v_batch.id,'points_added',v_points,'stamps_added',v_stamps));
 return jsonb_build_object('ok',true,'points_added',v_points,'stamps_added',v_stamps,'points_balance',v_account.points_balance,'stamps_balance',v_account.stamps_balance);
end; $$;
revoke all on function private.admin_create_qr_batch(uuid,uuid,integer,integer,timestamptz) from public,anon,authenticated;
revoke all on function private.admin_list_qr_batches(integer) from public,anon,authenticated;
revoke all on function private.admin_get_qr_batch_print_data(uuid) from public,anon,authenticated;
revoke all on function private.admin_revoke_qr_batch(uuid) from public,anon,authenticated;
revoke all on function public.admin_create_qr_batch(uuid,uuid,integer,integer,timestamptz) from public,anon;
revoke all on function public.admin_list_qr_batches(integer) from public,anon;
revoke all on function public.admin_get_qr_batch_print_data(uuid) from public,anon;
revoke all on function public.admin_revoke_qr_batch(uuid) from public,anon;
revoke all on function public.claim_admin_qr_code(text) from public,anon;
grant execute on function public.admin_create_qr_batch(uuid,uuid,integer,integer,timestamptz) to authenticated;
grant execute on function public.admin_list_qr_batches(integer) to authenticated;
grant execute on function public.admin_get_qr_batch_print_data(uuid) to authenticated;
grant execute on function public.admin_revoke_qr_batch(uuid) to authenticated;
grant execute on function public.claim_admin_qr_code(text) to authenticated;


-- Preserve stable serial order across repeat-print operations.
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


-- Keep the privileged claim implementation outside the exposed API schema.
alter function public.claim_admin_qr_code(text) set schema private;
alter function private.claim_admin_qr_code(text) security definer;
alter function private.claim_admin_qr_code(text) set search_path='';
revoke all on function private.claim_admin_qr_code(text) from public,anon,authenticated;
grant usage on schema private to authenticated;
grant execute on function private.claim_admin_qr_code(text) to authenticated;
create or replace function public.claim_admin_qr_code(p_code text)
returns jsonb language sql security invoker set search_path=''
as $$ select private.claim_admin_qr_code($1); $$;
revoke all on function public.claim_admin_qr_code(text) from public,anon;
grant execute on function public.claim_admin_qr_code(text) to authenticated;

-- Public SECURITY INVOKER wrappers call these permission-checking private SECURITY DEFINER routines.
grant execute on function private.admin_create_qr_batch(uuid,uuid,integer,integer,timestamptz) to authenticated;
grant execute on function private.admin_list_qr_batches(integer) to authenticated;
grant execute on function private.admin_get_qr_batch_print_data(uuid) to authenticated;
grant execute on function private.admin_revoke_qr_batch(uuid) to authenticated;
