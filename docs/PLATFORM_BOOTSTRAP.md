# WATHAQ-CORE first administrator bootstrap

The platform console stays hidden until an authenticated user is explicitly inserted into `public.platform_admins`. Never grant platform-admin status from user metadata or from the browser.

1. Create the first administrator account through WATHAQ-CORE Auth using the phone OTP flow.
2. Complete SMS verification and confirm the account has a verified E.164 phone number.
3. In the Supabase SQL Editor for project `ncfromrlnlotrwkgjenk`, replace the placeholder with the exact verified phone number and run:

```sql
insert into public.platform_admins(user_id)
select id
from auth.users
where phone = '+967XXXXXXXXX'
  and phone_confirmed_at is not null
on conflict (user_id) do nothing;
```

4. Sign out and sign in again so the client reloads the administrator membership.
5. The Administration tab appears. Merchant status transitions are guarded by a database trigger and every decision is written to `audit_events`.

## Phone OTP prerequisite

The customer, merchant, and employee sign-in flows use phone OTP. Before real users can sign in, configure and test an SMS provider in Supabase Auth → Providers → Phone. Verify delivery to Yemeni networks, expiry, resend limits, abuse protection, and account recovery. No SMS provider credentials belong in this repository.
