-- !!! NOT YET APPLIED to wathaq-dev and NOT YET TESTED (the database connector lost authentication on 2026-11-02).
-- Apply with the SQL editor or CLI, then run supabase/tests/staff_kpi_tests.sql and require every line to be PASS.
-- Staff management and merchant KPIs as audited server functions; direct client writes to merchant_staff are removed.
create function private.mask_contact(ph text, em text) returns text language sql immutable set search_path = '' as $$
  select case
    when coalesce(ph, '') <> '' then '+' || left(ltrim(ph, '+'), 3) || ' ' || substr(ltrim(ph, '+'), 4, 1) || '•• ••• ' || right(ph, 3)
    when coalesce(em, '') <> '' then left(em, 1) || '•••' || substr(em, position('@' in em))
    else '—' end;
$$;

create function public.invite_staff(p_merchant_id uuid, p_phone text default null, p_email text default null, p_permissions text[] default array['issue_earn']) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); ph text := nullif(regexp_replace(coalesce(p_phone, ''), '[\s\-()]', '', 'g'), ''); em text := nullif(lower(trim(coalesce(p_email, ''))), ''); tgt uuid; perms text[];
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not private.is_merchant_owner(p_merchant_id) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if private.recent_fails('staff.invite_attempt', 60) >= 10 then return jsonb_build_object('ok', false, 'error', 'rate_limited'); end if;
  perform private.log('staff.invite_attempt', 'merchant', p_merchant_id::text);
  if (ph is null) = (em is null) or (ph is not null and ph !~ '^\+?\d{8,15}$') or (em is not null and em !~ '^\S+@\S+\.\S+$') then
    return jsonb_build_object('ok', false, 'error', 'invalid_input'); end if;
  if p_permissions is null or cardinality(p_permissions) = 0 or not (p_permissions <@ array['issue_earn', 'confirm_redeem']) then
    return jsonb_build_object('ok', false, 'error', 'invalid_permissions'); end if;
  perms := array(select distinct x from unnest(p_permissions) x order by x);
  if ph is not null then select id into tgt from auth.users where phone = any (array[ph, ltrim(ph, '+')]);
  else select id into tgt from auth.users where lower(email) = em; end if;
  if tgt is null then return jsonb_build_object('ok', false, 'error', 'user_not_found'); end if;
  if tgt = uid then return jsonb_build_object('ok', false, 'error', 'invalid_input'); end if;
  insert into public.merchant_staff(merchant_id, user_id, permissions, is_active) values (p_merchant_id, tgt, perms, true)
    on conflict (merchant_id, user_id) do update set permissions = excluded.permissions, is_active = true;
  perform private.log('staff.invited', 'merchant', p_merchant_id::text, jsonb_build_object('user_ref', right(tgt::text, 4), 'permissions', perms));
  return jsonb_build_object('ok', true, 'user_id', tgt, 'ref', right(tgt::text, 4), 'permissions', perms);
end $$;

create function public.list_staff(p_merchant_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare arr jsonb;
begin
  if (select auth.uid()) is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not private.is_merchant_owner(p_merchant_id) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  select coalesce(jsonb_agg(jsonb_build_object('user_id', s.user_id, 'ref', right(s.user_id::text, 4), 'contact', private.mask_contact(u.phone, u.email),
    'permissions', s.permissions, 'is_active', s.is_active, 'created_at', s.created_at) order by s.created_at), '[]'::jsonb)
    into arr from public.merchant_staff s join auth.users u on u.id = s.user_id where s.merchant_id = p_merchant_id;
  return jsonb_build_object('ok', true, 'staff', arr);
end $$;

create function public.set_staff(p_merchant_id uuid, p_user_id uuid, p_permissions text[] default null, p_active boolean default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare perms text[];
begin
  if (select auth.uid()) is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not private.is_merchant_owner(p_merchant_id) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if not exists (select 1 from public.merchant_staff where merchant_id = p_merchant_id and user_id = p_user_id) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if p_permissions is not null then
    if cardinality(p_permissions) = 0 or not (p_permissions <@ array['issue_earn', 'confirm_redeem']) then return jsonb_build_object('ok', false, 'error', 'invalid_permissions'); end if;
    perms := array(select distinct x from unnest(p_permissions) x order by x);
  end if;
  update public.merchant_staff set permissions = coalesce(perms, permissions), is_active = coalesce(p_active, is_active) where merchant_id = p_merchant_id and user_id = p_user_id;
  perform private.log('staff.updated', 'merchant', p_merchant_id::text, jsonb_build_object('user_ref', right(p_user_id::text, 4), 'permissions', perms, 'active', p_active));
  return jsonb_build_object('ok', true);
end $$;

create function public.merchant_kpis(p_merchant_id uuid) returns jsonb
language plpgsql security definer stable set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not private.is_merchant_owner(p_merchant_id) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  return jsonb_build_object('ok', true,
    'members', (select count(*) from public.cards where merchant_id = p_merchant_id),
    'active_30d', (select count(distinct customer_id) from public.transactions where merchant_id = p_merchant_id and type = 'earn' and created_at > now() - interval '30 days'),
    'earn_30d', (select count(*) from public.transactions where merchant_id = p_merchant_id and type = 'earn' and created_at > now() - interval '30 days'),
    'redeem_30d', (select count(*) from public.transactions where merchant_id = p_merchant_id and type = 'redeem' and created_at > now() - interval '30 days'));
end $$;

revoke execute on function private.mask_contact(text, text) from public, anon;
revoke execute on function public.invite_staff(uuid, text, text, text[]), public.list_staff(uuid), public.set_staff(uuid, uuid, text[], boolean), public.merchant_kpis(uuid) from public, anon;
grant execute on function public.invite_staff(uuid, text, text, text[]), public.list_staff(uuid), public.set_staff(uuid, uuid, text[], boolean), public.merchant_kpis(uuid) to authenticated;
revoke insert, update, delete on public.merchant_staff from authenticated;
