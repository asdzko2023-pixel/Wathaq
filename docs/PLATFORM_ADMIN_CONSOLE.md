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
- Platform administrators can activate/deactivate non-owner merchant memberships through `admin_set_merchant_member_active`; every change is written to `audit_events`. Owner memberships are protected.
- Platform administrators can create 48-hour staff invitations for active merchants, choose from the allowed staff permission set, list invitation states, and revoke unused invitations. Invitation codes are shown once and stored only as SHA-256 digests; creation and revocation are audited.

## Deliberately not implemented yet
The browser must not query `auth.users` or directly administer user roles. Platform-admin RBAC, merchant staff administration, plans/subscriptions, platform settings workflows, fraud alerts, and exports require narrowly scoped, authenticated, audited server-side RPCs and matching tests before their controls are enabled. The user directory remains read-only until non-admin denial and pagination/search tests are completed.

## Hosting
Deploy the contents of `platform-admin/` as a static site or under a dedicated `/admin` path. It references `../app/config.js` and `../packages/design-tokens/tokens.css`; preserve these relative paths or adjust them deliberately for the chosen hosting root.

## Verification still required
- Run the web CI and inspect its result.
- Add a test identity to `platform_admins` through the approved SQL bootstrap after confirming the exact account.
- Test login, non-admin denial, merchant status transitions, audit event creation, and mobile layout against WATHAQ-CORE.
- This foundation is not a production-ready admin release until the above tests and the remaining secure RPCs are complete.


## Permission-scoped operator access

The console now reads `admin_get_my_permissions` after sign-in and filters navigation and actions by the returned database permissions. The same permission checks are enforced inside the RPCs and the merchant-status trigger; the browser-side checks are only presentation controls. The public merchant-status RPC is a SECURITY INVOKER wrapper around a private SECURITY DEFINER implementation.

| Role | Effective scope |
|---|---|
| `support_viewer` | Read user profiles, merchants, staff, loyalty summaries, and audit |
| `merchant_operator` | Read merchants/staff, change merchant status, manage staff status and invitations, read audit |
| `loyalty_operator` | Read loyalty data, manage program lifecycle and reward activation, read audit |
| `analytics_viewer` | Read aggregate analytics and audit |

Super Admin remains a separate allowlist in `platform_admins`; operator memberships cannot promote a user into Super Admin. Revoking an operator membership removes the permissions on the next RPC request.

## Analytics

The analytics page uses `admin_get_analytics_report`, a read-only aggregate RPC. It reports user/merchant/program/reward counts and 30-day ledger activity by day and kind without returning customer identifiers. It is available only to `analytics.read` and Super Admin.

## Validation boundaries

- GitHub Actions validates JavaScript syntax, RPC wiring, and migration presence.
- SQL tests exercised each seeded role's permission boundary, disabled-membership revocation, Super Admin analytics report shape, unauthenticated denial, and a temporary merchant status update with its audit trigger. The temporary merchant and membership were rolled back in the test block.
- The role-matrix SQL tests used a temporary existing profile membership and removed it within the same test block.
- A real browser sign-in/session test for an operator account and a live authenticated non-admin HTTP denial test remain outstanding. The SQL permission tests simulate the Supabase JWT subject claim; they are not a substitute for an HTTP session test.
- Subscription rules and writable platform settings remain unimplemented until their commercial and operational rules are specified; no fake plans or settings are exposed.


## Loyalty program validity window

Customer join, check-in QR issuance, redemption QR issuance, and earn/redeem confirmation now reject programs outside their configured `starts_at` / `ends_at` window, even if the program state remains active. Internal `can_issue_earn` and `can_confirm_redeem` helper functions are no longer directly executable by authenticated clients; their trusted SECURITY DEFINER API functions continue to call them.


## Secure bulk QR factory

- The platform admin console includes a permission-gated QR factory for active points/stamps programs. Super Admin and the `loyalty.qr.manage` permission can create batches of 1–1,000 codes with a fixed value and required expiry (maximum 365 days).
- Codes contain 128 bits of cryptographically random entropy. SHA-256 digests are unique within the QR factory and checked against existing loyalty token digests before insertion.
- Printable code material is stored only as AES-256 encrypted ciphertext under a private database-held key; plaintext is returned only during initial creation or an authorized, audited reprint. Private tables and key are not granted to API roles.
- Reprinting returns the original codes and never creates new ones. Revocation changes every still-issued code in the batch to revoked. Consumed codes remain consumed.
- `claim_admin_qr_code` is the customer-side atomic claim RPC: it locks the code row, validates batch/merchant/program/expiry, creates or locks the customer's loyalty account, credits the fixed points/stamps amount, writes ledger and audit records, and marks the code consumed in one transaction.
- The admin UI renders QR labels in a print-ready browser page; the browser print dialog can save the layout as PDF. The admin UI and database feature are implemented, but the Flutter customer scan/claim screen still requires integration and device-level end-to-end testing before customer redemption is live.
