alter function public.claim_admin_qr_code(text) set schema private;
alter function private.claim_admin_qr_code(text) security definer;
alter function private.claim_admin_qr_code(text) set search_path='';
revoke all on function private.claim_admin_qr_code(text) from public,anon,authenticated;
grant usage on schema private to authenticated;
grant execute on function private.claim_admin_qr_code(text) to authenticated;
create or replace function public.claim_admin_qr_code(p_code text)
returns jsonb language sql security invoker set search_path=''
as $$ select private.claim_admin_qr_code($1); $$;
revoke all on function public.claim_admin_qr_code(text) from public,anon;
grant execute on function public.claim_admin_qr_code(text) to authenticated;
