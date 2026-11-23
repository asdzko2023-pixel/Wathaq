-- Super Admin-only platform merchant creation.
create or replace function private.admin_create_merchant(
  p_owner_user_id uuid,
  p_name text,
  p_slug text,
  p_category text default null,
  p_description text default null,
  p_country_code text default 'YE',
  p_city text default null,
  p_address text default null,
  p_phone text default null,
  p_email text default null,
  p_timezone text default 'Asia/Aden'
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_merchant public.merchants%rowtype;
  v_name text := nullif(trim(p_name), '');
  v_slug text := lower(trim(p_slug));
  v_country text := upper(trim(coalesce(p_country_code, 'YE')));
  v_timezone text := coalesce(nullif(trim(p_timezone), ''), 'Asia/Aden');
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_platform_admin() then
    raise exception 'only super admin can create platform merchants' using errcode = '42501';
  end if;
  if p_owner_user_id is null or not exists(select 1 from auth.users u where u.id = p_owner_user_id) then
    raise exception 'owner account not found' using errcode = '22023';
  end if;
  if v_name is null or char_length(v_name) not between 2 and 120 then
    raise exception 'merchant name must be 2 to 120 characters' using errcode = '22023';
  end if;
  if v_slug is null or v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' or char_length(v_slug) > 80 then
    raise exception 'slug must contain lowercase letters, numbers and single hyphens' using errcode = '22023';
  end if;
  if char_length(v_country) <> 2 or v_country !~ '^[A-Z]{2}$' then
    raise exception 'country code must be ISO alpha-2' using errcode = '22023';
  end if;
  if not exists(select 1 from pg_catalog.pg_timezone_names t where t.name = v_timezone) then
    raise exception 'unknown timezone' using errcode = '22023';
  end if;
  if exists(select 1 from public.merchants m where lower(m.slug) = v_slug) then
    raise exception 'merchant slug already exists' using errcode = '23505';
  end if;
  insert into public.merchants(
    owner_user_id, name, slug, category, description, country_code,
    city, address, phone, email, timezone, status
  ) values (
    p_owner_user_id, v_name, v_slug, nullif(trim(p_category), ''),
    nullif(trim(p_description), ''), v_country, nullif(trim(p_city), ''),
    nullif(trim(p_address), ''), nullif(trim(p_phone), ''),
    nullif(lower(trim(p_email)), ''), v_timezone, 'pending'
  ) returning * into v_merchant;

  insert into public.audit_events(
    actor_user_id, merchant_id, action, entity_type, entity_id, details
  ) values (
    v_actor, v_merchant.id, 'platform.merchant_created', 'merchant',
    v_merchant.id::text,
    jsonb_build_object(
      'name', v_merchant.name,
      'slug', v_merchant.slug,
      'owner_user_id', v_merchant.owner_user_id,
      'initial_status', v_merchant.status,
      'creation_source', 'platform_admin'
    )
  );
  return jsonb_build_object(
    'ok', true, 'merchant_id', v_merchant.id, 'name', v_merchant.name,
    'slug', v_merchant.slug, 'status', v_merchant.status,
    'owner_user_id', v_merchant.owner_user_id
  );
end;
$$;

create or replace function public.admin_create_merchant(
  p_owner_user_id uuid,
  p_name text,
  p_slug text,
  p_category text default null,
  p_description text default null,
  p_country_code text default 'YE',
  p_city text default null,
  p_address text default null,
  p_phone text default null,
  p_email text default null,
  p_timezone text default 'Asia/Aden'
) returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.admin_create_merchant($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11);
$$;

revoke all on function private.admin_create_merchant(uuid,text,text,text,text,text,text,text,text,text,text) from public, anon, authenticated;
grant execute on function private.admin_create_merchant(uuid,text,text,text,text,text,text,text,text,text,text) to authenticated;
revoke all on function public.admin_create_merchant(uuid,text,text,text,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.admin_create_merchant(uuid,text,text,text,text,text,text,text,text,text,text) to authenticated;
