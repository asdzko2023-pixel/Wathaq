-- DEV ONLY. Run in the Supabase SQL editor of the dev project after you have signed in once with each account.
-- Replace the placeholders. Never run on production.

-- 1) Make your account the owner of the three demo stores (is_test = true):
update public.merchants
set owner_id = (select id from auth.users where email = 'YOUR_EMAIL@example.com')
where is_test;

-- 2) Add a staff member to "مقهى النموذج" (by email; or use phone = '+967777000002'):
insert into public.merchant_staff (merchant_id, user_id, permissions)
select m.id, u.id, array['issue_earn', 'confirm_redeem']
from public.merchants m, auth.users u
where m.name = 'مقهى النموذج' and u.email = 'STAFF_EMAIL@example.com'
on conflict (merchant_id, user_id) do update set permissions = excluded.permissions, is_active = true;

-- 3) Optional: make your account a platform admin (needed later for the admin console):
insert into public.platform_admins (user_id)
select id from auth.users where email = 'YOUR_EMAIL@example.com'
on conflict do nothing;
