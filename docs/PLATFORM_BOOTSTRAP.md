# WATHAQ-CORE first administrator bootstrap

The platform console stays hidden until an authenticated user is explicitly inserted into `public.platform_admins`. Never grant platform-admin status from user metadata or from the browser.

1. Enable Google OAuth in WATHAQ-CORE by following `docs/GOOGLE_AUTH_SETUP.md`.
2. Sign in to WATHAQ using the exact Google account intended for the first platform administrator.
3. Verify the Google account email is confirmed in Supabase Auth → Users.
4. In the Supabase SQL Editor for project `ncfromrlnlotrwkgjenk`, replace the placeholder with that exact Google email and run:

```sql
insert into public.platform_admins(user_id)
select id
from auth.users
where lower(email) = lower('admin@example.com')
  and email_confirmed_at is not null
on conflict (user_id) do nothing;
```

5. Sign out and sign in again so the client reloads the administrator membership.
6. The Administration tab appears. Merchant status transitions are guarded by a database trigger and every decision is written to `audit_events`.

## Google OAuth prerequisite

Customer, merchant, and employee sign-in use the same Google OAuth flow. Before real users can sign in, configure the Google OAuth Web client and enable the Google provider in Supabase Auth. Configure the exact application Site URL and Redirect URLs. Keep the Google Client Secret out of this repository and never assign platform-admin privileges based on an email supplied by browser metadata. The bootstrap SQL only selects an already authenticated, email-confirmed Auth user.
