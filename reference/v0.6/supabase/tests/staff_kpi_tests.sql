-- !!! NOT YET RUN. Tests for 20261102000001_phase4_staff_and_kpi_functions.sql. DEV project only; ends with an intentional rollback.
create function pg_temp.r(name text, ok boolean) returns text language sql as $$ select name || ': ' || case when coalesce(ok,false) then 'PASS' else 'FAIL' end || E'\n' $$;
create function pg_temp.u(x uuid) returns void language plpgsql as $$ begin perform set_config('request.jwt.claims', json_build_object('sub', x, 'role', 'authenticated')::text, true); execute 'set local role authenticated'; end $$;
create function pg_temp.su() returns void language plpgsql as $$ begin execute 'reset role'; end $$;
do $$
declare O uuid := gen_random_uuid(); O2 uuid := gen_random_uuid(); S uuid := gen_random_uuid(); X uuid := gen_random_uuid(); Z uuid := gen_random_uuid(); Y uuid := gen_random_uuid(); C uuid := gen_random_uuid();
  M1 uuid; M2 uuid; P1 uuid; cC uuid; v jsonb; res text := ''; i int; got_rl boolean := false;
begin
  insert into auth.users(id,aud,role,email,phone,created_at,updated_at) values
    (O,'authenticated','authenticated','owner@t.local',null,now(),now()),(O2,'authenticated','authenticated','owner2@t.local',null,now(),now()),
    (S,'authenticated','authenticated','staff@t.local',null,now(),now()),(X,'authenticated','authenticated','x@t.local',null,now(),now()),
    (Z,'authenticated','authenticated','Zed@T.local',null,now(),now()),(Y,'authenticated','authenticated',null,'967700000009',now(),now()),
    (C,'authenticated','authenticated','c@t.local',null,now(),now());
  insert into public.merchants(owner_id,name,status,is_test) values (O,'M1','approved',true) returning id into M1;
  insert into public.merchants(owner_id,name,status,is_test) values (O2,'M2','approved',true) returning id into M2;
  insert into public.merchant_staff(merchant_id,user_id,permissions) values (M1,S,'{issue_earn}');
  insert into public.programs(merchant_id,type,name,rules,status) values (M1,'stamps','P1','{"target":3}','active') returning id into P1;
  perform pg_temp.u(X); v := public.invite_staff(M1, null, 'z@t.local');
  res := res || pg_temp.r('I01 a customer cannot invite', v->>'error'='forbidden');
  perform pg_temp.u(S); v := public.invite_staff(M1, null, 'z@t.local');
  res := res || pg_temp.r('I02 staff cannot invite', v->>'error'='forbidden');
  perform pg_temp.u(O2); v := public.invite_staff(M1, null, 'z@t.local');
  res := res || pg_temp.r('I03 another store owner cannot invite into this store', v->>'error'='forbidden');
  perform pg_temp.u(O); v := public.invite_staff(M1, null, '  z@T.local ', array['confirm_redeem','confirm_redeem']);
  res := res || pg_temp.r('I04 owner invites by email (case-insensitive, de-duplicated permissions)', (v->>'ok')::boolean and v->'permissions'='["confirm_redeem"]'::jsonb);
  v := public.invite_staff(M1, '+967 700 000 009', null, array['issue_earn']);
  res := res || pg_temp.r('I05 owner invites by phone stored without the plus sign', (v->>'ok')::boolean);
  v := public.invite_staff(M1, '+967711111111', null);
  res := res || pg_temp.r('I06 unknown user gets user_not_found', v->>'error'='user_not_found');
  v := public.invite_staff(M1, null, 'z@t.local', array['superadmin']);
  res := res || pg_temp.r('I07 permissions outside the model are refused', v->>'error'='invalid_permissions');
  v := public.invite_staff(M1, null, 'z@t.local', array[]::text[]);
  res := res || pg_temp.r('I08 empty permissions are refused', v->>'error'='invalid_permissions');
  v := public.invite_staff(M1, '+967700000009', 'z@t.local');
  res := res || pg_temp.r('I09 both phone and email is invalid', v->>'error'='invalid_input');
  v := public.invite_staff(M1, null, 'owner@t.local');
  res := res || pg_temp.r('I10 an owner cannot invite themselves', v->>'error'='invalid_input');
  perform pg_temp.u(O2);
  for i in 1..12 loop v := public.invite_staff(M2, null, 'nobody' || i || '@t.local'); if v->>'error'='rate_limited' then got_rl := true; end if; end loop;
  res := res || pg_temp.r('I11 invitations are rate limited', got_rl);
  perform pg_temp.u(O); v := public.list_staff(M1);
  res := res || pg_temp.r('L01 owner lists staff with masked contacts only', (v->>'ok')::boolean and jsonb_array_length(v->'staff')=3 and position('staff@t.local' in v::text)=0 and position('967700000009' in v::text)=0);
  perform pg_temp.u(X); v := public.list_staff(M1);
  res := res || pg_temp.r('L02 non-owner cannot list staff', v->>'error'='forbidden');
  perform pg_temp.u(S); v := public.issue_earn_code(P1);
  res := res || pg_temp.r('S00 invited staff with the permission can issue', (v->>'ok')::boolean);
  perform pg_temp.u(O); v := public.set_staff(M1, S, null, false);
  perform pg_temp.u(S); v := public.issue_earn_code(P1);
  res := res || pg_temp.r('S01 deactivated staff immediately lose access', v->>'error'='forbidden');
  perform pg_temp.u(O); v := public.set_staff(M1, S, array['issue_earn','confirm_redeem'], true);
  perform pg_temp.u(S); v := public.issue_earn_code(P1);
  res := res || pg_temp.r('S02 reactivation restores access', (v->>'ok')::boolean);
  perform pg_temp.u(X); v := public.set_staff(M1, S, null, false);
  res := res || pg_temp.r('S03 non-owner cannot change staff', v->>'error'='forbidden');
  perform pg_temp.u(O); v := public.set_staff(M1, S, array['bogus'], null);
  res := res || pg_temp.r('S04 invalid permissions refused on update', v->>'error'='invalid_permissions');
  begin insert into public.merchant_staff(merchant_id,user_id,permissions) values (M1,X,'{issue_earn}'); res := res || pg_temp.r('S05 direct table writes are no longer allowed', false);
  exception when insufficient_privilege then res := res || pg_temp.r('S05 direct table writes are no longer allowed', true); end;
  perform pg_temp.su();
  insert into public.cards(customer_id,program_id,merchant_id,stamps) values (C,P1,M1,2) returning id into cC;
  insert into public.transactions(card_id,customer_id,merchant_id,program_id,type,amount,idempotency_key) values (cC,C,M1,P1,'earn',1,'k1'),(cC,C,M1,P1,'earn',1,'k2'),(cC,C,M1,P1,'redeem',-3,'k3');
  perform pg_temp.u(O); v := public.merchant_kpis(M1);
  res := res || pg_temp.r('K01 kpis count members, distinct active customers, earn and redeem', (v->>'members')::int=1 and (v->>'active_30d')::int=1 and (v->>'earn_30d')::int=2 and (v->>'redeem_30d')::int=1);
  perform pg_temp.u(S); v := public.merchant_kpis(M1);
  res := res || pg_temp.r('K02 staff cannot read owner kpis', v->>'error'='forbidden');
  perform pg_temp.su();
  res := res || pg_temp.r('A01 audit rows exist for invites and updates', (select count(distinct action) from public.audit_logs where action in ('staff.invite_attempt','staff.invited','staff.updated'))=3);
  perform pg_temp.su(); execute 'set local role anon';
  begin perform public.list_staff(M1); res := res || pg_temp.r('X01 anonymous cannot call', false);
  exception when insufficient_privilege then res := res || pg_temp.r('X01 anonymous cannot call', true); end;
  perform pg_temp.su();
  raise exception E'\n===RESULTS===\n%', res;
end $$;
