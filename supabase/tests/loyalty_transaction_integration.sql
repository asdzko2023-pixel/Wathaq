-- End-to-end WATHAQ Core loyalty transaction test.
-- Run as a privileged SQL test connection. All fixtures are rolled back.
begin;

create temporary table wathaq_test_state (
 merchant_id uuid, program_id uuid, account_id uuid, reward_id uuid,
 stamps_program_id uuid, stamps_account_id uuid, stamps_reward_id uuid,
 invite_code text, earn_code text, redeem_code text, stamps_earn_code text, stamps_redeem_code text,
 unauthorized_earn_error text, earn_replay_error text, redeem_replay_error text, stamps_replay_error text
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
select case when
 (select char_length(earn_code)=16 and unauthorized_earn_error='not_authorized' from wathaq_test_state)
then 'PASS: customer cannot confirm an earn token and token entropy is 64 bits'
else (1/0)::text end;

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

-- Repeat the full lifecycle for a stamps program with a minimum-purchase rule.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into public.loyalty_programs(id,merchant_id,name,kind,state,currency_code,stamp_goal,rules)
values('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','WATHAQ Test Stamps','stamps','active','YER',5,'{"minimum_purchase":20}');
insert into public.rewards(id,merchant_id,program_id,title,stamps_cost,is_active)
values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','Test Stamp Reward',1,true);
update wathaq_test_state set stamps_program_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd',stamps_reward_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
update wathaq_test_state set stamps_account_id=public.join_loyalty_program(stamps_program_id);
update wathaq_test_state set stamps_earn_code=(public.create_customer_checkin_code(stamps_program_id)->>'code');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select public.confirm_earn_code(stamps_earn_code,25) from wathaq_test_state;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
update wathaq_test_state set stamps_redeem_code=(public.create_redeem_code(stamps_account_id,stamps_reward_id)->>'code');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select public.confirm_redeem_code(stamps_redeem_code) from wathaq_test_state;
update wathaq_test_state set stamps_replay_error=(public.confirm_redeem_code(stamps_redeem_code)->>'error');

reset role;
select case when
 (select points_balance=50 and lifetime_points=100 from public.loyalty_accounts where id=(select account_id from wathaq_test_state))
 and (select count(*)=2 from public.loyalty_ledger where account_id=(select account_id from wathaq_test_state))
 and (select stamps_balance=0 and lifetime_stamps=1 from public.loyalty_accounts where id=(select stamps_account_id from wathaq_test_state))
 and (select count(*)=2 from public.loyalty_ledger where account_id=(select stamps_account_id from wathaq_test_state))
 and (select earn_replay_error='code_used' and redeem_replay_error='code_used' and stamps_replay_error='code_used' from wathaq_test_state)
 and not has_table_privilege('authenticated','public.loyalty_accounts','UPDATE')
 and not has_table_privilege('authenticated','public.loyalty_ledger','INSERT')
then 'PASS: points, stamps, earn/redeem, replay protection, immutable ledger and client privilege boundaries'
else (1/0)::text end;

rollback;
