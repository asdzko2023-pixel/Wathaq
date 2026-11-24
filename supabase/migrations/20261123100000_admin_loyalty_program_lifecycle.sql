-- Controlled lifecycle transitions for loyalty programs from the platform console.
create or replace function private.admin_set_loyalty_program_state(p_program_id uuid,p_state public.program_state)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare v_program public.loyalty_programs%rowtype; v_merchant_state public.merchant_state;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.is_platform_admin() then raise exception 'platform administrator required' using errcode='42501'; end if;
 if p_program_id is null or p_state is null then raise exception 'program and target state are required' using errcode='22023'; end if;
 select * into v_program from public.loyalty_programs where id=p_program_id for update;
 if not found then raise exception 'loyalty program not found' using errcode='P0002'; end if;
 if v_program.state=p_state then return jsonb_build_object('ok',true,'changed',false,'state',v_program.state); end if;
 if v_program.state='archived' then return jsonb_build_object('ok',false,'error','archived_is_terminal'); end if;
 if not ((v_program.state='draft' and p_state in ('active','archived'))
      or (v_program.state='active' and p_state in ('paused','archived'))
      or (v_program.state='paused' and p_state in ('active','archived'))) then
   return jsonb_build_object('ok',false,'error','invalid_state_transition');
 end if;
 if p_state='active' then
   select status into v_merchant_state from public.merchants where id=v_program.merchant_id;
   if v_merchant_state is distinct from 'active'::public.merchant_state then
     return jsonb_build_object('ok',false,'error','merchant_not_active');
   end if;
 end if;
 update public.loyalty_programs set state=p_state where id=p_program_id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details)
 values((select auth.uid()),v_program.merchant_id,'platform.loyalty_program_state_changed','loyalty_program',p_program_id::text,
 jsonb_build_object('previous_state',v_program.state,'new_state',p_state,'program_name',v_program.name));
 return jsonb_build_object('ok',true,'changed',true,'state',p_state);
end;$function$;
revoke all on function private.admin_set_loyalty_program_state(uuid,public.program_state) from public,anon;
grant execute on function private.admin_set_loyalty_program_state(uuid,public.program_state) to authenticated;
create or replace function public.admin_set_loyalty_program_state(p_program_id uuid,p_state public.program_state)
returns jsonb language sql security invoker set search_path = ''
as $function$ select private.admin_set_loyalty_program_state($1,$2); $function$;
revoke all on function public.admin_set_loyalty_program_state(uuid,public.program_state) from public,anon;
grant execute on function public.admin_set_loyalty_program_state(uuid,public.program_state) to authenticated;
