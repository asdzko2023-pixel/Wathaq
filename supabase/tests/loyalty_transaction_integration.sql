-- End-to-end WATHAQ Core loyalty transaction test.
-- Run as a privileged SQL test connection. All fixtures are rolled back.
begin;

create temporary table wathaq_test_state (
 merchant_id uuid, program_id uuid, account_id uuid, reward_id uuid,
 invite_code text, earn_code text, redeem_code text,
 unauthorized_earn_error text, earn_replay_error text, redeem_replay_error text
) on commit drop;
grant select,insert,update on wathaq_test_state to authenticated;

insert into auth.users(id,aud,role,phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('11111111-1111-4111-8111-111111111111','authenticated','authenticated','+967777000001',now(),'{}','{"full_name":"WATHAQ test owner"}',now(),now()),
 ('22222222-2222-4222-8222-222222222222','authenticated','authenticated','+967777000002',now(),'{}','{"full_name":"WATHAQ test customer"}',now(),now()),
 ('33333333-3333-4333-8333-333333333333','authenticated','authenticated','+967777000003',now(),'{}','{"full_name":"WATHAQ test staff"}',now(),now()),
 ('44444444-4444-4444-8444-444444444444','authenticated','authenticated','+967777000004',now(),'{}','{"full_name":"WATHAQ test platform admin"}',now(),now());

insert into public.platform_admins(user_id) values('44444444-4444-4444-8444-444444444444');

-- Merchant owner creates a pending merchant; platform admin approves it.
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into public.merchants(id,owner_user_id,name,slug,status,city)
values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','WATHAQ Test Merchant','wathaq-test-merchant','pending','Aden');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
update public.merchants set status='active' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

-- Owner publishes a points program and configures a reward.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into public.loyalty_programs(id,merchant_id,name,kind,state,currency_code,points_per_currency)
values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','WATHAQ Test Points','points','active','YER',1);
insert into public.rewards(id,merchant_id,program_id,title,points_cost,is_active)
values('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Test Reward',50,true);
insert into wathaq_test_state(merchant_id,program_id,reward_id)
values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','cccccccc-cccc-4ccc-8ccc-cccccccccccc');

-- Owner invites staff; staff accepts with the same verified phone.
update wathaq_test_state set invite_code=(public.create_merchant_invite(
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','+967777000003',array['issue_earn','confirm_redeem']
)->>'code');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select public.accept_merchant_invite(invite_code) from wathaq_test_state;

-- Customer joins, receives a one-time QR payload; customer cannot confirm it.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
update wathaq_test_state set account_id=public.join_loyalty_program(program_id);
update wathaq_test_state set earn_code=(public.create_customer_checkin_code(program_id)->>'code');
update wathaq_test_state set unauthorized_earn_error=(
 public.confirm_earn_code(earn_code,100)->>'error'
);
do $$
begin
 if (select char_length(earn_code) from wathaq_test_state)<>16 then raise exception 'FAIL: earn token must be 16 hex characters'; end if;
 if (select unauthorized_earn_error from wathaq_test_state)<>'not_authorized' then raise exception 'FAIL: customer was able to confirm earn token'; end if;
end $$;

-- Authorized staff confirms the purchase; replay must be rejected.
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select public.confirm_earn_code(earn_code,100) from wathaq_test_state;
update wathaq_test_state set earn_replay_error=(public.confirm_earn_code(earn_code,100)->>'error');

-- Customer requests reward redemption; authorized staff confirms once.
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
update wathaq_test_state set redeem_code=(public.create_redeem_code(account_id,reward_id)->>'code');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select public.confirm_redeem_code(redeem_code) from wathaq_test_state;
update wathaq_test_state set redeem_replay_error=(public.confirm_redeem_code(redeem_code)->>'error');

reset role;
do $$
declare v_balance bigint; v_lifetime bigint; v_entries integer; v_earn_replay text; v_redeem_replay text;
begin
 select points_balance,lifetime_points into v_balance,v_lifetime
 from public.loyalty_accounts where id=(select account_id from wathaq_test_state);
 select count(*) into v_entries from public.loyalty_ledger where account_id=(select account_id from wathaq_test_state);
 select earn_replay_error,redeem_replay_error into v_earn_replay,v_redeem_replay from wathaq_test_state;
 if v_balance<>50 or v_lifetime<>100 or v_entries<>2 then
  raise exception 'FAIL: expected balance 50, lifetime earned 100 and two ledger rows; got %, %, %',v_balance,v_lifetime,v_entries;
 end if;
 if v_earn_replay<>'code_used' or v_redeem_replay<>'code_used' then
  raise exception 'FAIL: one-time token replay was not rejected';
 end if;
 if has_table_privilege('authenticated','public.loyalty_accounts','UPDATE')
    or has_table_privilege('authenticated','public.loyalty_ledger','INSERT') then
  raise exception 'FAIL: client role has direct balance or ledger write privileges';
 end if;
 raise notice 'PASS: merchant approval, staff invite, customer join, earn, redeem, replay protection, immutable ledger and client privilege boundaries';
end $$;

rollback;
