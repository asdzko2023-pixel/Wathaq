create or replace function private.admin_list_qr_eligible_programs()
returns table(program_id uuid,merchant_id uuid,merchant_name text,program_name text,kind public.loyalty_program_kind,starts_at timestamptz,ends_at timestamptz)
language plpgsql security definer set search_path=''
as $$
begin
 if (select auth.uid()) is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not(private.is_platform_admin() or private.has_platform_permission('loyalty.qr.manage')) then raise exception 'not authorized' using errcode='42501'; end if;
 return query select p.id,m.id,m.name,p.name,p.kind,p.starts_at,p.ends_at
 from public.loyalty_programs p join public.merchants m on m.id=p.merchant_id
 where p.state='active' and m.status='active' and (p.starts_at is null or p.starts_at<=now()) and (p.ends_at is null or p.ends_at>now())
 order by m.name,p.name;
end; $$;
create or replace function public.admin_list_qr_eligible_programs()
returns table(program_id uuid,merchant_id uuid,merchant_name text,program_name text,kind public.loyalty_program_kind,starts_at timestamptz,ends_at timestamptz)
language sql security invoker set search_path=''
as $$ select * from private.admin_list_qr_eligible_programs(); $$;
revoke all on function private.admin_list_qr_eligible_programs() from public,anon,authenticated;
grant execute on function private.admin_list_qr_eligible_programs() to authenticated;
revoke all on function public.admin_list_qr_eligible_programs() from public,anon;
grant execute on function public.admin_list_qr_eligible_programs() to authenticated;
