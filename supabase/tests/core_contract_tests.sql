-- WATHAQ CORE schema contract checks. Run with a privileged SQL test connection.
do $$
declare v_count integer; v_bad text;
begin
  select count(*) into v_count
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r' and not c.relrowsecurity;
  if v_count>0 then raise exception 'FAIL: % public tables have RLS disabled',v_count; end if;

  if has_table_privilege('authenticated','public.loyalty_accounts','UPDATE')
     or has_table_privilege('authenticated','public.loyalty_ledger','INSERT')
     or has_table_privilege('authenticated','public.loyalty_ledger','UPDATE')
     or has_table_privilege('authenticated','public.loyalty_tokens','SELECT')
     or has_table_privilege('authenticated','public.loyalty_tokens','INSERT')
     or has_table_privilege('authenticated','public.merchant_invites','SELECT')
     or has_table_privilege('authenticated','public.merchant_invites','INSERT') then
    raise exception 'FAIL: client role has direct access to protected loyalty state or invitation records';
  end if;

  if has_function_privilege('anon','public.join_loyalty_program(uuid)','EXECUTE')
     or has_function_privilege('anon','public.create_customer_checkin_code(uuid)','EXECUTE')
     or has_function_privilege('anon','public.confirm_earn_code(text,numeric)','EXECUTE')
     or has_function_privilege('anon','public.create_redeem_code(uuid,uuid)','EXECUTE')
     or has_function_privilege('anon','public.confirm_redeem_code(text)','EXECUTE')
     or has_function_privilege('anon','public.create_merchant_invite(uuid,text,text[])','EXECUTE')
     or has_function_privilege('anon','public.accept_merchant_invite(text)','EXECUTE') then
    raise exception 'FAIL: anonymous role can execute a protected loyalty RPC';
  end if;

  select count(*) into v_count
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname in ('join_loyalty_program','create_customer_checkin_code','confirm_earn_code','create_redeem_code','confirm_redeem_code')
    and p.prosecdef and coalesce(array_to_string(p.proconfig,','),'') like '%search_path=""%';
  if v_count<>5 then raise exception 'FAIL: expected 5 hardened SECURITY DEFINER RPCs, found %',v_count; end if;


  -- Internal SECURITY DEFINER helpers must never be callable by API roles.
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='private'
      and (has_function_privilege('anon',p.oid,'EXECUTE')
        or has_function_privilege('authenticated',p.oid,'EXECUTE'))
  ) then
    raise exception 'FAIL: private helper/trigger function is executable by a client role';
  end if;

  -- All public RPC entry points must be explicitly authenticated and hardened.
  select count(*) into v_count
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname = any(array[
      'accept_merchant_invite','confirm_earn_code','confirm_redeem_code',
      'create_customer_checkin_code','create_merchant_invite','create_redeem_code',
      'join_loyalty_program','list_merchant_members','set_merchant_member'
    ])
    and p.prosecdef
    and coalesce(array_to_string(p.proconfig,','),'') like '%search_path=""%'
    and pg_get_functiondef(p.oid) like '%auth.uid()%'
    and has_function_privilege('authenticated',p.oid,'EXECUTE')
    and not has_function_privilege('anon',p.oid,'EXECUTE');
  if v_count<>9 then raise exception 'FAIL: expected 9 authenticated-only hardened RPCs, found %',v_count; end if;

  raise notice 'PASS: public RLS, protected balances, private tokens, and hardened RPC grants';
end $$;
