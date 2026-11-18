# WATHAQ-CORE first administrator bootstrap

The platform console intentionally stays hidden until a real authenticated user is explicitly inserted into public.platform_admins. Do not grant platform-admin status from user metadata or from the browser.

1. Create the first administrator's account through WATHAQ-CORE Auth and verify the email/phone.
2. In the Supabase SQL Editor for project ncfromrlnlotrwkgjenk, run the statement below after replacing the placeholder with that administrator's exact verified phone:

```sql
insert into public.platform_admins(user_id)
select id
from auth.users
where lower(email) = lower('REPLACE_WITH_VERIFIED_ADMIN_EMAIL')
  and email_confirmed_at is not null
on conflict (user_id) do nothing;
```

3. Sign out and sign in again so the client reloads the admin membership.
4. The Administration tab will appear. Merchant status changes are guarded by a database trigger and every decision is written to audit_events.

## Phone OTP prerequisite

The customer and employee sign-in currently use phone OTP. Before real users can sign in, configure and test an SMS provider in Supabase Auth > Providers > Phone. Keep OTP expiry and request limits strict. No SMS provider credentials are stored in this repository.
