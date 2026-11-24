create or replace function private.admin_get_analytics_report(p_days integer default 30)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
 v_days integer:=least(greatest(coalesce(p_days,30),7),90);
 v_trend jsonb;
 v_kinds jsonb;
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.has_platform_permission('analytics.read') then raise exception 'permission denied' using errcode='42501'; end if;

 select coalesce(jsonb_agg(to_jsonb(d) order by d.day),'[]'::jsonb) into v_trend
 from (
   select series.day::date as day,
     count(l.id)::bigint as ledger_entries,
     coalesce(sum(case when l.kind='earn' and l.points_delta>0 then l.points_delta else 0 end),0)::bigint as points_earned,
     coalesce(sum(case when l.kind='redeem' and l.points_delta<0 then abs(l.points_delta) else 0 end),0)::bigint as points_redeemed
   from generate_series(current_date-(v_days-1),current_date,interval '1 day') as series(day)
   left join public.loyalty_ledger l on l.created_at>=series.day and l.created_at<series.day+interval '1 day'
   group by series.day
 ) d;

 select coalesce(jsonb_agg(to_jsonb(k) order by k.kind),'[]'::jsonb) into v_kinds
 from (
   select kind::text as kind,count(*)::bigint as entries,
     coalesce(sum(points_delta),0)::bigint as points_delta
   from public.loyalty_ledger
   where created_at>=now()-make_interval(days=>v_days)
   group by kind
 ) k;

 return jsonb_build_object(
   'period_days',v_days,
   'generated_at',now(),
   'users_total',(select count(*) from public.profiles),
   'merchants_total',(select count(*) from public.merchants),
   'merchants_active',(select count(*) from public.merchants where status='active'),
   'merchants_pending',(select count(*) from public.merchants where status='pending'),
   'programs_total',(select count(*) from public.loyalty_programs),
   'programs_active',(select count(*) from public.loyalty_programs where state='active'),
   'rewards_total',(select count(*) from public.rewards),
   'rewards_active',(select count(*) from public.rewards where is_active),
   'loyalty_accounts_total',(select count(*) from public.loyalty_accounts),
   'ledger_entries_period',(select count(*) from public.loyalty_ledger where created_at>=now()-make_interval(days=>v_days)),
   'points_earned_period',(select coalesce(sum(points_delta),0) from public.loyalty_ledger where kind='earn' and points_delta>0 and created_at>=now()-make_interval(days=>v_days)),
   'points_redeemed_period',(select coalesce(sum(abs(points_delta)),0) from public.loyalty_ledger where kind='redeem' and points_delta<0 and created_at>=now()-make_interval(days=>v_days)),
   'trend',v_trend,
   'ledger_by_kind',v_kinds
 );
end;
$function$;

create or replace function public.admin_get_analytics_report(p_days integer default 30)
returns jsonb
language sql
security invoker
set search_path=''
as $function$ select private.admin_get_analytics_report($1); $function$;
revoke all on function private.admin_get_analytics_report(integer) from public,anon;
grant execute on function private.admin_get_analytics_report(integer) to authenticated;
revoke all on function public.admin_get_analytics_report(integer) from public,anon;
grant execute on function public.admin_get_analytics_report(integer) to authenticated;
