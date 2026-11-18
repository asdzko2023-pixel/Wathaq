-- Phase 3: server-side earn and redeem. Clients never write balances; every change goes through these functions.
-- Business failures RETURN {"ok":false,"error":"..."} (so audit rows commit); only auth problems RAISE.
create extension if not exists pgcrypto with schema extensions;

alter table public.reward_tokens
  add column amount int check (amount is null or amount > 0),
  add column reference text,
  add column card_id uuid references public.cards(id),
  add column reward_id uuid references public.rewards(id),
  add column used_by uuid;
create index reward_tokens_card_idx on public.reward_tokens(card_id) where kind = 'redeem' and status = 'active';
create index reward_tokens_issuer_idx on public.reward_tokens(created_by, created_at desc);
alter table public.merchant_staff add constraint staff_permissions_allowed
  check (permissions <@ array['issue_earn','confirm_redeem']::text[]);
insert into public.platform_settings(key, value) values ('earn_code_ttl_seconds', '120'), ('redeem_code_ttl_seconds', '300')
  on conflict (key) do nothing;

create function private.gen_code() returns text language plpgsql volatile set search_path = '' as $$
declare a constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea := extensions.gen_random_bytes(8); r text := ''; i int;
begin
  for i in 0..7 loop r := r || substr(a, (get_byte(b, i) % 32) + 1, 1); end loop;
  return substr(r, 1, 4) || '-' || substr(r, 5, 4);
end $$;
create function private.hash_code(c text) returns text language sql immutable set search_path = '' as $$
  select encode(extensions.digest(upper(regexp_replace(coalesce(c, ''), '[^A-Za-z0-9]', '', 'g')), 'sha256'), 'hex');
$$;
create function private.ttl(k text, d int) returns int language sql stable set search_path = '' as $$
  select coalesce((select (value #>> '{}')::int from public.platform_settings where key = k), d);
$$;
create function private.staff_can(mid uuid, perm text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.merchants m
    where m.id = mid and m.status = 'approved' and (
      m.owner_id = (select auth.uid())
      or exists (select 1 from public.merchant_staff s where s.merchant_id = m.id and s.user_id = (select auth.uid()) and s.is_active and perm = any (s.permissions))));
$$;
create function private.log(a text, ent text, eid text, d jsonb default '{}') returns void
language sql security definer set search_path = '' as $$
  insert into public.audit_logs(actor_id, action, entity, entity_id, details) values ((select auth.uid()), a, ent, eid, d);
$$;
create function private.recent_fails(a text, mins int default 10) returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.audit_logs where actor_id = (select auth.uid()) and action = a and created_at > now() - make_interval(mins => mins);
$$;

create function public.issue_earn_code(p_program_id uuid, p_amount int default null, p_reference text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); pr record; amt int; mx int; code text; h text; tries int := 0; exp timestamptz;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  select p.id, p.merchant_id, p.type, p.rules into pr from public.programs p where p.id = p_program_id and p.status = 'active';
  if not found or not private.staff_can(pr.merchant_id, 'issue_earn') then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if (select count(*) from public.reward_tokens where created_by = uid and kind = 'earn' and created_at > now() - interval '1 minute') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited'); end if;
  amt := coalesce(p_amount, (pr.rules ->> 'per_code')::int, 1);
  mx := coalesce((pr.rules ->> 'max_per_code')::int, case when pr.type = 'stamps' then 5 else 1000 end);
  if amt < 1 or amt > mx then return jsonb_build_object('ok', false, 'error', 'invalid_amount', 'max', mx); end if;
  exp := now() + make_interval(secs => private.ttl('earn_code_ttl_seconds', 120));
  loop
    code := private.gen_code(); h := private.hash_code(code);
    begin
      insert into public.reward_tokens(merchant_id, program_id, kind, token_hash, status, expires_at, created_by, amount, reference)
      values (pr.merchant_id, pr.id, 'earn', h, 'active', exp, uid, amt, left(p_reference, 60));
      exit;
    exception when unique_violation then
      tries := tries + 1; if tries > 5 then raise exception 'code generation failed'; end if;
    end;
  end loop;
  perform private.log('earn.code_issued', 'program', pr.id::text, jsonb_build_object('amount', amt, 'merchant_id', pr.merchant_id));
  return jsonb_build_object('ok', true, 'code', code, 'expires_at', exp, 'amount', amt);
end $$;

create function public.claim_earn_code(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); h text := private.hash_code(p_code); t record; c record; pg record; ns int; np int; txid uuid; tx record;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not private.phone_verified() then return jsonb_build_object('ok', false, 'error', 'phone_not_verified'); end if;
  if private.recent_fails('earn.claim_failed') >= 8 then return jsonb_build_object('ok', false, 'error', 'too_many_attempts'); end if;
  select * into t from public.reward_tokens where token_hash = h and kind = 'earn' for update;
  if not found then perform private.log('earn.claim_failed', 'token', null, '{"why":"invalid"}'); return jsonb_build_object('ok', false, 'error', 'invalid_code'); end if;
  if t.status = 'used' then
    if t.used_by = uid then
      select amount, card_id into tx from public.transactions where idempotency_key = 'earn:' || t.id;
      return jsonb_build_object('ok', true, 'replay', true, 'added', tx.amount, 'card_id', tx.card_id);
    end if;
    perform private.log('earn.claim_failed', 'token', t.id::text, '{"why":"used"}'); return jsonb_build_object('ok', false, 'error', 'code_used');
  end if;
  if t.status <> 'active' then perform private.log('earn.claim_failed', 'token', t.id::text, '{"why":"unavailable"}'); return jsonb_build_object('ok', false, 'error', 'code_unavailable'); end if;
  if t.expires_at <= now() then
    update public.reward_tokens set status = 'expired' where id = t.id;
    perform private.log('earn.claim_failed', 'token', t.id::text, '{"why":"expired"}'); return jsonb_build_object('ok', false, 'error', 'code_expired'); end if;
  select p.type, p.version, m.name into pg from public.programs p join public.merchants m on m.id = p.merchant_id
    where p.id = t.program_id and p.status = 'active' and m.status = 'approved';
  if not found then return jsonb_build_object('ok', false, 'error', 'program_unavailable'); end if;
  select * into c from public.cards where customer_id = uid and program_id = t.program_id for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_joined', 'program_id', t.program_id); end if;
  update public.cards set stamps = stamps + case when pg.type = 'stamps' then t.amount else 0 end,
                          points = points + case when pg.type = 'points' then t.amount else 0 end
    where id = c.id returning stamps, points into ns, np;
  insert into public.transactions(card_id, customer_id, merchant_id, program_id, type, amount, reason, program_version, idempotency_key, created_by)
    values (c.id, uid, t.merchant_id, t.program_id, 'earn', t.amount, 'earn_code', pg.version, 'earn:' || t.id, t.created_by) returning id into txid;
  update public.reward_tokens set status = 'used', used_at = now(), used_by = uid, customer_id = uid, card_id = c.id where id = t.id;
  perform private.log('earn.claimed', 'card', c.id::text, jsonb_build_object('token_id', t.id, 'amount', t.amount));
  return jsonb_build_object('ok', true, 'replay', false, 'type', pg.type, 'added', t.amount, 'balance', case when pg.type = 'stamps' then ns else np end, 'merchant', pg.name, 'card_id', c.id);
end $$;

create function public.request_redeem(p_card_id uuid, p_reward_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); c record; r record; bal int; code text; h text; tries int := 0; exp timestamptz;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not private.phone_verified() then return jsonb_build_object('ok', false, 'error', 'phone_not_verified'); end if;
  select * into c from public.cards where id = p_card_id and customer_id = uid for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  select r2.id, r2.title, r2.cost, r2.merchant_id, p.type into r from public.rewards r2
    join public.programs p on p.id = r2.program_id join public.merchants m on m.id = r2.merchant_id
    where r2.id = p_reward_id and r2.program_id = c.program_id and r2.is_active and p.status = 'active' and m.status = 'approved';
  if not found then return jsonb_build_object('ok', false, 'error', 'reward_unavailable'); end if;
  bal := case when r.type = 'stamps' then c.stamps else c.points end;
  if bal < r.cost then return jsonb_build_object('ok', false, 'error', 'insufficient_balance', 'need', r.cost - bal); end if;
  if (select count(*) from public.reward_tokens where created_by = uid and kind = 'redeem' and created_at > now() - interval '1 minute') >= 5 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited'); end if;
  update public.reward_tokens set status = 'cancelled' where kind = 'redeem' and card_id = c.id and reward_id = r.id and status = 'active';
  exp := now() + make_interval(secs => private.ttl('redeem_code_ttl_seconds', 300));
  loop
    code := private.gen_code(); h := private.hash_code(code);
    begin
      insert into public.reward_tokens(merchant_id, program_id, kind, token_hash, customer_id, status, expires_at, created_by, card_id, reward_id)
      values (r.merchant_id, c.program_id, 'redeem', h, uid, 'active', exp, uid, c.id, r.id);
      exit;
    exception when unique_violation then
      tries := tries + 1; if tries > 5 then raise exception 'code generation failed'; end if;
    end;
  end loop;
  perform private.log('redeem.requested', 'card', c.id::text, jsonb_build_object('reward_id', r.id));
  return jsonb_build_object('ok', true, 'code', code, 'expires_at', exp, 'reward', r.title, 'cost', r.cost);
end $$;

create function public.confirm_redeem(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := (select auth.uid()); h text := private.hash_code(p_code); t record; c record; r record; bal int; nb int; tx record;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if private.recent_fails('redeem.confirm_failed') >= 8 then return jsonb_build_object('ok', false, 'error', 'too_many_attempts'); end if;
  select * into t from public.reward_tokens where token_hash = h and kind = 'redeem' for update;
  if not found then perform private.log('redeem.confirm_failed', 'token', null, '{"why":"invalid"}'); return jsonb_build_object('ok', false, 'error', 'invalid_code'); end if;
  if not private.staff_can(t.merchant_id, 'confirm_redeem') then
    perform private.log('redeem.confirm_failed', 'token', t.id::text, '{"why":"wrong_store"}'); return jsonb_build_object('ok', false, 'error', 'wrong_store'); end if;
  if t.status = 'used' then
    if t.used_by = uid then
      select amount into tx from public.transactions where idempotency_key = 'redeem:' || t.id;
      return jsonb_build_object('ok', true, 'replay', true, 'deducted', -tx.amount);
    end if;
    perform private.log('redeem.confirm_failed', 'token', t.id::text, '{"why":"used"}'); return jsonb_build_object('ok', false, 'error', 'code_used');
  end if;
  if t.status <> 'active' then return jsonb_build_object('ok', false, 'error', 'code_unavailable'); end if;
  if t.expires_at <= now() then
    update public.reward_tokens set status = 'expired' where id = t.id;
    perform private.log('redeem.confirm_failed', 'token', t.id::text, '{"why":"expired"}'); return jsonb_build_object('ok', false, 'error', 'code_expired'); end if;
  select * into c from public.cards where id = t.card_id for update;
  select r2.title, r2.cost, p.type, p.version into r from public.rewards r2 join public.programs p on p.id = r2.program_id
    where r2.id = t.reward_id and r2.is_active and p.status = 'active';
  if not found then return jsonb_build_object('ok', false, 'error', 'reward_unavailable'); end if;
  bal := case when r.type = 'stamps' then c.stamps else c.points end;
  if bal < r.cost then return jsonb_build_object('ok', false, 'error', 'insufficient_balance'); end if;
  update public.cards set stamps = stamps - case when r.type = 'stamps' then r.cost else 0 end,
                          points = points - case when r.type = 'points' then r.cost else 0 end
    where id = c.id returning case when r.type = 'stamps' then stamps else points end into nb;
  insert into public.transactions(card_id, customer_id, merchant_id, program_id, type, amount, reason, program_version, idempotency_key, created_by)
    values (c.id, c.customer_id, t.merchant_id, t.program_id, 'redeem', -r.cost, 'redeem: ' || r.title, r.version, 'redeem:' || t.id, uid);
  update public.reward_tokens set status = 'used', used_at = now(), used_by = uid where id = t.id;
  perform private.log('redeem.confirmed', 'card', c.id::text, jsonb_build_object('token_id', t.id, 'cost', r.cost));
  return jsonb_build_object('ok', true, 'replay', false, 'reward', r.title, 'deducted', r.cost, 'balance', nb, 'customer_ref', right(c.customer_id::text, 4));
end $$;

revoke execute on all functions in schema private from public, anon;
grant execute on function private.staff_can(uuid, text) to authenticated;
revoke execute on function public.issue_earn_code(uuid, int, text), public.claim_earn_code(text),
  public.request_redeem(uuid, uuid), public.confirm_redeem(text) from public, anon;
grant execute on function public.issue_earn_code(uuid, int, text), public.claim_earn_code(text),
  public.request_redeem(uuid, uuid), public.confirm_redeem(text) to authenticated;
