-- Restricted reward catalogue and audited activation controls for platform administrators.
create or replace function private.admin_list_rewards(p_search text default null,p_limit integer default 100)
returns table(reward_id uuid,merchant_id uuid,merchant_name text,program_id uuid,program_name text,title text,description text,points_cost integer,stamps_cost integer,stock_quantity integer,is_active boolean,created_at timestamptz)
language plpgsql security definer set search_path = ''
as $function$
declare v_search text:=nullif(left(btrim(coalesce(p_search,'')),100),''); v_limit integer:=least(greatest(coalesce(p_limit,100),1),200);
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.is_platform_admin() then raise exception 'platform administrator required' using errcode='42501'; end if;
 return query select r.id,r.merchant_id,m.name,r.program_id,p.name,r.title,r.description,r.points_cost,r.stamps_cost,r.stock_quantity,r.is_active,r.created_at
 from public.rewards r join public.merchants m on m.id=r.merchant_id join public.loyalty_programs p on p.id=r.program_id
 where v_search is null or r.title ilike '%'||v_search||'%' or m.name ilike '%'||v_search||'%' or p.name ilike '%'||v_search||'%'
 order by r.created_at desc limit v_limit;
end;$function$;
create or replace function private.admin_set_reward_active(p_reward_id uuid,p_active boolean)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare v_reward public.rewards%rowtype; v_program_state public.program_state; v_merchant_state public.merchant_state;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.is_platform_admin() then raise exception 'platform administrator required' using errcode='42501'; end if;
 if p_reward_id is null or p_active is null then raise exception 'reward and target state required' using errcode='22023'; end if;
 select * into v_reward from public.rewards where id=p_reward_id for update;
 if not found then raise exception 'reward not found' using errcode='P0002'; end if;
 if v_reward.is_active=p_active then return jsonb_build_object('ok',true,'changed',false,'is_active',v_reward.is_active); end if;
 if p_active then
  select state into v_program_state from public.loyalty_programs where id=v_reward.program_id;
  select status into v_merchant_state from public.merchants where id=v_reward.merchant_id;
  if v_program_state is distinct from 'active'::public.program_state or v_merchant_state is distinct from 'active'::public.merchant_state then
   return jsonb_build_object('ok',false,'error','active_program_and_merchant_required');
  end if;
 end if;
 update public.rewards set is_active=p_active where id=p_reward_id;
 insert into public.audit_events(actor_user_id,merchant_id,action,entity_type,entity_id,details)
 values((select auth.uid()),v_reward.merchant_id,'platform.reward_status_changed','reward',p_reward_id::text,
 jsonb_build_object('previous_active',v_reward.is_active,'active',p_active,'title',v_reward.title));
 return jsonb_build_object('ok',true,'changed',true,'is_active',p_active);
end;$function$;
revoke all on function private.admin_list_rewards(text,integer) from public,anon;
revoke all on function private.admin_set_reward_active(uuid,boolean) from public,anon;
grant execute on function private.admin_list_rewards(text,integer) to authenticated;
grant execute on function private.admin_set_reward_active(uuid,boolean) to authenticated;
create or replace function public.admin_list_rewards(p_search text default null,p_limit integer default 100)
returns table(reward_id uuid,merchant_id uuid,merchant_name text,program_id uuid,program_name text,title text,description text,points_cost integer,stamps_cost integer,stock_quantity integer,is_active boolean,created_at timestamptz)
language sql security invoker set search_path = ''
as $function$ select * from private.admin_list_rewards($1,$2); $function$;
create or replace function public.admin_set_reward_active(p_reward_id uuid,p_active boolean)
returns jsonb language sql security invoker set search_path = ''
as $function$ select private.admin_set_reward_active($1,$2); $function$;
revoke all on function public.admin_list_rewards(text,integer) from public,anon;
revoke all on function public.admin_set_reward_active(uuid,boolean) from public,anon;
grant execute on function public.admin_list_rewards(text,integer) to authenticated;
grant execute on function public.admin_set_reward_active(uuid,boolean) to authenticated;
