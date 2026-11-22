# WATHAQ Platform Admin Console

## Surface
The standalone administration web surface lives in `platform-admin/`. It is separate from the customer Flutter application and uses the existing WATHAQ-CORE Supabase project and shared design tokens.

## Authentication and authorization
- Uses the public/publishable Supabase key from `app/config.js`; no service-role key or database password is permitted in browser assets.
- Google OAuth signs the operator in through Supabase Auth.
- The console checks the signed-in user's ID against `public.platform_admins`. A successful login alone never grants platform privileges.
- Bootstrap the first administrator only through the reviewed procedure in `docs/PLATFORM_BOOTSTRAP.md`. Never set role metadata from the browser.
- All data access remains subject to database grants and RLS.

## Available in this foundation
- Platform overview counts for merchants, loyalty accounts, ledger rows, and audit events.
- Merchant listing and search. Status changes call the narrowly scoped `admin_set_merchant_status` RPC, which requires a platform-admin membership; the existing database trigger records the change in `audit_events`.
- Read-only views for loyalty programs, recent ledger entries, loyalty account balances, and audit events.
- A restricted user-profile directory through `admin_list_user_profiles`, returning only user ID, display name, locale, and profile creation date. It does not query `auth.users`, email addresses, phone numbers, or authentication metadata.
- A restricted merchant-staff membership directory through `admin_list_merchant_staff`, returning merchant, member ID, role, permission labels, active state, and membership date.
- Platform administrators can activate/deactivate non-owner merchant memberships through `admin_set_merchant_member_active`; every change is written to `audit_events`. Owner memberships are protected. Invitations and permission editing remain pending.

## Deliberately not implemented yet
The browser must not query `auth.users` or directly administer user roles. Platform-admin RBAC, merchant staff administration, plans/subscriptions, platform settings workflows, fraud alerts, and exports require narrowly scoped, authenticated, audited server-side RPCs and matching tests before their controls are enabled. The user directory remains read-only until non-admin denial and pagination/search tests are completed.

## Hosting
Deploy the contents of `platform-admin/` as a static site or under a dedicated `/admin` path. It references `../app/config.js` and `../packages/design-tokens/tokens.css`; preserve these relative paths or adjust them deliberately for the chosen hosting root.

## Verification still required
- Run the web CI and inspect its result.
- Add a test identity to `platform_admins` through the approved SQL bootstrap after confirming the exact account.
- Test login, non-admin denial, merchant status transitions, audit event creation, and mobile layout against WATHAQ-CORE.
- This foundation is not a production-ready admin release until the above tests and the remaining secure RPCs are complete.
