-- Run against a DEV project only (SQL editor or MCP execute_sql). The block ends with an intentional
-- exception so every row it creates is rolled back; the exception text IS the report.
create function pg_temp.r(name text, ok boolean) returns text language sql as $$ select name || ': ' || case when ok then 'PASS' else 'FAIL' end || E'\n' $$;
do $$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid(); adm uuid := gen_random_uuid();
  m1 uuid; p1 uuid; card1 uuid; card2 uuid; n int; v int; res text := ''; tier text; pv boolean;
begin
  insert into auth.users(id,aud,role,email,created_at,updated_at) values
    (a,'authenticated','authenticated','a@test.local',now(),now()),(b,'authenticated','authenticated','b@test.local',now(),now()),
    (c,'authenticated','authenticated','c@test.local',now(),now()),(adm,'authenticated','authenticated','adm@test.local',now(),now());
  insert into public.platform_admins(user_id) values (adm);
  select count(*) into n from public.profiles where id in (a,b,c,adm);
  res := res || pg_temp.r('T01 signup trigger creates profiles', n=4);

  perform set_config('request.jwt.claims', json_build_object('sub',a,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  update public.profiles set display_name='A' where id=a; get diagnostics n = row_count;
  res := res || pg_temp.r('T02 customer updates own profile', n=1);
  update public.profiles set display_name='x' where id=b; get diagnostics n = row_count;
  res := res || pg_temp.r('T03 customer cannot update others profile', n=0);
  begin insert into public.platform_admins(user_id) values (a); res := res || pg_temp.r('T04 customer cannot make self admin', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T04 customer cannot make self admin', true); end;
  begin update public.cards set stamps=99; res := res || pg_temp.r('T05 customer cannot write card balance', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T05 customer cannot write card balance', true); end;
  begin insert into public.transactions(card_id,customer_id,merchant_id,program_id,type,amount,idempotency_key)
        values (gen_random_uuid(),a,gen_random_uuid(),gen_random_uuid(),'earn',1,'forge1');
        res := res || pg_temp.r('T06 customer cannot forge transaction', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T06 customer cannot forge transaction', true); end;
  begin perform 1 from public.reward_tokens; res := res || pg_temp.r('T07 customer cannot read reward_tokens', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T07 customer cannot read reward_tokens', true); end;
  begin insert into public.merchants(owner_id,name) values (b,'Spoof');
        res := res || pg_temp.r('T08 cannot create merchant owned by someone else', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T08 cannot create merchant owned by someone else', true); end;
  begin insert into public.merchants(owner_id,name,status) values (a,'Self','approved');
        res := res || pg_temp.r('T09 cannot self-approve merchant on insert', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T09 cannot self-approve merchant on insert', true); end;
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub',b,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  insert into public.merchants(owner_id,name,category,city) values (b,'Test Cafe','cafe','Aden') returning id into m1;
  res := res || pg_temp.r('T10 owner creates merchant (pending)', (select status from public.merchants where id=m1)='pending');
  begin update public.merchants set status='approved' where id=m1; res := res || pg_temp.r('T11 owner cannot approve own merchant', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T11 owner cannot approve own merchant', true); end;
  begin update public.merchants set owner_id=c where id=m1; res := res || pg_temp.r('T12 owner cannot change owner_id', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T12 owner cannot change owner_id', true); end;
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub',adm,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  update public.merchants set status='approved' where id=m1; get diagnostics n = row_count;
  res := res || pg_temp.r('T13 admin approves merchant', n=1);
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub',b,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  insert into public.programs(merchant_id,type,name,rules,status) values (m1,'stamps','Loyalty','{"target":8}','active') returning id into p1;
  res := res || pg_temp.r('T14 owner creates active program', p1 is not null);
  insert into public.rewards(program_id,merchant_id,title,cost) values (p1,m1,'Free coffee',8);
  res := res || pg_temp.r('T15 owner creates reward', true);
  update public.programs set rules='{"target":10}' where id=p1;
  select version into v from public.programs where id=p1;
  res := res || pg_temp.r('T16 rules change bumps version', v=2);
  execute 'reset role';
  select count(*) into n from public.audit_logs where action='program.rules_changed' and entity_id=p1::text;
  res := res || pg_temp.r('T17 rules change audited', n=1);

  update auth.users set phone='+967700000001' where id=a;
  perform set_config('request.jwt.claims', json_build_object('sub',a,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  select private.phone_verified() into pv;
  res := res || pg_temp.r('T18 phone_verified false before OTP confirm', pv=false);
  card1 := public.join_program(p1); card2 := public.join_program(p1);
  res := res || pg_temp.r('T19 join_program idempotent (same card)', card1=card2 and card1 is not null);
  select count(*) into n from public.cards;
  res := res || pg_temp.r('T20 customer sees only own card', n=1);
  select public.my_tier() into tier;
  res := res || pg_temp.r('T21 new customer tier = bronze', tier='bronze');
  execute 'reset role';
  update auth.users set phone_confirmed_at=now() where id=a;
  perform set_config('request.jwt.claims', json_build_object('sub',a,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  select private.phone_verified() into pv;
  res := res || pg_temp.r('T22 phone_verified true after confirm', pv=true);
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub',c,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.cards where merchant_id=m1;
  res := res || pg_temp.r('T23 other merchant cannot read cards', n=0);
  begin insert into public.merchant_staff(merchant_id,user_id) values (m1,c);
        res := res || pg_temp.r('T24 other user cannot add staff to my merchant', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T24 other user cannot add staff to my merchant', true); end;
  begin insert into public.programs(merchant_id,type,name) values (m1,'points','Hijack');
        res := res || pg_temp.r('T25 other user cannot create program on my merchant', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T25 other user cannot create program on my merchant', true); end;
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub',b,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.cards where merchant_id=m1;
  res := res || pg_temp.r('T26 owner reads own merchant cards', n=1);
  execute 'reset role';

  execute 'set local role anon';
  begin perform 1 from public.merchants; res := res || pg_temp.r('T27 anon cannot read merchants', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T27 anon cannot read merchants', true); end;
  execute 'reset role';

  insert into public.transactions(card_id,customer_id,merchant_id,program_id,type,amount,idempotency_key) values (card1,a,m1,p1,'earn',1,'k1');
  begin update public.transactions set amount=100 where idempotency_key='k1'; res := res || pg_temp.r('T28 transactions immutable (update)', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T28 transactions immutable (update)', true); end;
  begin delete from public.transactions where idempotency_key='k1'; res := res || pg_temp.r('T29 transactions immutable (delete)', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T29 transactions immutable (delete)', true); end;
  begin update public.audit_logs set action='x'; res := res || pg_temp.r('T30 audit_logs immutable', false);
  exception when insufficient_privilege then res := res || pg_temp.r('T30 audit_logs immutable', true); end;
  begin insert into public.transactions(card_id,customer_id,merchant_id,program_id,type,amount,idempotency_key) values (card1,a,m1,p1,'earn',1,'k1');
        res := res || pg_temp.r('T31 duplicate idempotency key rejected', false);
  exception when unique_violation then res := res || pg_temp.r('T31 duplicate idempotency key rejected', true); end;
  begin insert into public.cards(customer_id,program_id,merchant_id,stamps) values (b,p1,m1,-1);
        res := res || pg_temp.r('T32 negative balance rejected', false);
  exception when check_violation then res := res || pg_temp.r('T32 negative balance rejected', true); end;

  raise exception E'\n===TEST RESULTS===\n%', res;
end $$;
