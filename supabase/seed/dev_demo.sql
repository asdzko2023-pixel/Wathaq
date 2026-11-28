-- DEV ONLY demo data, flagged is_test = true. Never run on a production project.
-- Also sets the OTP channel to SMS only (WhatsApp is postponed).
update public.platform_settings set value = '["sms"]'::jsonb, updated_at = now() where key = 'otp_channels';
do $$
declare o uuid; m1 uuid; m2 uuid; m3 uuid; p1 uuid; p2 uuid; p3 uuid;
begin
  if exists (select 1 from public.merchants where is_test) then return; end if;
  select id into o from auth.users where email = 'demo-owner@wathaq.test';
  if o is null then
    o := gen_random_uuid();
    insert into auth.users(id, aud, role, email, created_at, updated_at) values (o, 'authenticated', 'authenticated', 'demo-owner@wathaq.test', now(), now());
  end if;
  insert into public.merchants(owner_id, name, category, description, city, area, status, is_test) values (o, 'مقهى النموذج', 'المقاهي', 'مقهى مختص بالقهوة المحمصة محليًا.', 'عدن', 'كريتر', 'approved', true) returning id into m1;
  insert into public.merchants(owner_id, name, category, description, city, area, status, is_test) values (o, 'مخبز النموذج', 'الحلويات والمخابز', 'معجنات طازجة كل صباح.', 'عدن', 'المعلا', 'approved', true) returning id into m2;
  insert into public.merchants(owner_id, name, category, description, city, area, status, is_test) values (o, 'مطعم النموذج', 'المطاعم', 'مأكولات متنوعة للعائلات.', 'عدن', 'خور مكسر', 'approved', true) returning id into m3;
  insert into public.programs(merchant_id, type, name, rules, status) values (m1, 'stamps', 'أختام مقهى النموذج', '{"target":8,"earn_text":"ختم لكل مشروب مؤهل، وفق شروط المتجر.","redeem_text":"الاستبدال برمز مؤقت يؤكده موظف المتجر."}', 'active') returning id into p1;
  insert into public.programs(merchant_id, type, name, rules, status) values (m2, 'stamps', 'أختام مخبز النموذج', '{"target":6,"earn_text":"ختم لكل طلب مؤهل، وفق شروط المتجر.","redeem_text":"الاستبدال برمز مؤقت يؤكده موظف المتجر."}', 'active') returning id into p2;
  insert into public.programs(merchant_id, type, name, rules, status) values (m3, 'points', 'نقاط مطعم النموذج', '{"earn_text":"نقاط تُحتسب من فاتورتك المؤهلة، وفق قاعدة المتجر.","redeem_text":"الاستبدال برمز مؤقت يؤكده موظف المتجر."}', 'active') returning id into p3;
  insert into public.rewards(program_id, merchant_id, title, cost) values (p1, m1, 'قهوة مجانية', 8), (p2, m2, 'معجنات مجانية', 6), (p3, m3, 'عصير مجاني', 100), (p3, m3, 'طبق جانبي مجاني', 200);
end $$;
