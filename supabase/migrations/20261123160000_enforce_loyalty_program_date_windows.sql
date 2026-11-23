-- Restrict internal merchant authorization helpers from direct authenticated RPC use.
revoke all on function private.can_issue_earn(uuid) from public,anon,authenticated;
revoke all on function private.can_confirm_redeem(uuid) from public,anon,authenticated;

-- Program date windows must be enforced at both code issuance and code confirmation.
do $migration$
declare v_definition text; v_replacement text;
begin
 select pg_get_functiondef(p.oid) into v_definition from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='create_customer_checkin_code' and pg_get_function_identity_arguments(p.oid)='p_program_id uuid';
 if v_definition is null then raise exception 'create_customer_checkin_code missing'; end if;
 v_replacement:=replace(v_definition,
  $old$p.state='active'$old$,
  $new$p.state='active' and (p.starts_at is null or p.starts_at<=now()) and (p.ends_at is null or p.ends_at>now())$new$);
 if v_replacement=v_definition then raise exception 'check-in program state guard not found'; end if;
 execute v_replacement;

 select pg_get_functiondef(p.oid) into v_definition from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='join_loyalty_program' and pg_get_function_identity_arguments(p.oid)='p_program_id uuid';
 if v_definition is null then raise exception 'join_loyalty_program missing'; end if;
 v_replacement:=replace(v_definition,
  $old$p.state='active' and m.status='active'$old$,
  $new$p.state='active' and (p.starts_at is null or p.starts_at<=now()) and (p.ends_at is null or p.ends_at>now()) and m.status='active'$new$);
 if v_replacement=v_definition then raise exception 'join program state guard not found'; end if;
 execute v_replacement;

 select pg_get_functiondef(p.oid) into v_definition from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='create_redeem_code' and pg_get_function_identity_arguments(p.oid)='p_account_id uuid, p_reward_id uuid';
 if v_definition is null then raise exception 'create_redeem_code missing'; end if;
 v_replacement:=replace(v_definition,
  $old$where id=v_account.program_id and state='active'$old$,
  $new$where id=v_account.program_id and state='active' and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>now())$new$);
 if v_replacement=v_definition then raise exception 'redeem code program state guard not found'; end if;
 execute v_replacement;

 select pg_get_functiondef(p.oid) into v_definition from pg_proc p join pg_namespace n on n.oid=n.oid
 where n.nspname='public' and p.proname='confirm_redeem_code' and pg_get_function_identity_arguments(p.oid)='p_code text';
 if v_definition is null then raise exception 'confirm_redeem_code missing'; end if;
 v_replacement:=replace(v_definition,
  $old$where id=v_token.program_id and state='active'$old$,
  $new$where id=v_token.program_id and state='active' and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>now())$new$);
 if v_replacement=v_definition then raise exception 'confirm redeem program state guard not found'; end if;
 execute v_replacement;

 select pg_get_functiondef(p.oid) into v_definition from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='confirm_earn_code' and pg_get_function_identity_arguments(p.oid)='p_code text, p_purchase_amount numeric';
 if v_definition is null then raise exception 'confirm_earn_code missing'; end if;
 v_replacement:=replace(v_definition,
  $old$if v_program.state<>'active' then return jsonb_build_object('ok',false,'error','program_unavailable'); end if;$old$,
  $new$if v_program.state<>'active' or (v_program.starts_at is not null and v_program.starts_at>now()) or (v_program.ends_at is not null and v_program.ends_at<=now()) then return jsonb_build_object('ok',false,'error','program_unavailable'); end if;$new$);
 if v_replacement=v_definition then raise exception 'confirm earn program state guard not found'; end if;
 execute v_replacement;
end;
$migration$;
