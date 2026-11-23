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
The browser must not query `auth.users` or directly administer user roles. The platform-admin RBAC, merchant staff administration, and subscription workflows use narrowly scoped, authenticated, audited server-side RPCs. Platform settings workflows, fraud alerts, and exports remain future work. The user directory remains read-only.

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



## Merchant accounts and subscription plans

The Super Admin console now provides central merchant account creation and subscription management. New merchant account creation uses the `platform-create-merchant-account` Supabase Edge Function. The function verifies the caller's Supabase JWT and checks the caller's row in `platform_admins` with a server-only service key; it never exposes that key to the browser. A new owner receives a Supabase Auth invitation, while an already verified owner account can be linked without issuing a second identity. Unverified unrelated accounts are rejected rather than silently linked.

The Edge Function calls the authenticated `admin_create_merchant_account` RPC. Merchant insertion, automatic owner membership, initial plan assignment, subscription history, and audit event are one database transaction. Newly created merchants start in `pending` review state. An invitation that was sent before a database validation failure is retained as a pending invitation so the administrator can correct the input and retry using the same email; it does not create a merchant until the RPC succeeds.

### Monthly plans currently configured

| Plan | Monthly reference price | Staff seats | Active loyalty programs | QR codes / month |
| --- | ---: | ---: | ---: | ---: |
| WATHAQ STARTER | $9 | 2 | 1 | 500 |
| WATHAQ GROWTH | $19 | 5 | 3 | 2,500 |
| WATHAQ BUSINESS | $39 | 15 | 10 | 10,000 |
| WATHAQ ENTERPRISE | $99 | 50 | 30 | 50,000 |

The prices are administrative monthly reference prices. There is no payment gateway, automated billing, or automatic renewal connected yet. Billing status can be tagged as admin-assigned/unconfirmed, manually paid, or complimentary. Features stored under `planned_features` are explicitly not implemented and are not presented as enabled functionality.

### Subscription administration and enforcement

- The Super Admin can assign a plan to an existing legacy merchant, change/up-or-downgrade a plan, renew for 1–12 months, pause, reactivate an eligible paused subscription, cancel, or record manual payment/complimentary status. A merchant owner can read only their own current plan, expiry, quotas, and live/planned feature labels through `merchant_get_my_subscriptions`; the view is sourced from the database, so upgrades do not rely on stale user metadata.
- Each change writes both a subscription-history row and a platform audit event.
- Direct API access to plan, subscription, and history tables is revoked from anon/authenticated clients. The console reads and mutates through Super Admin-checked RPCs.
- Database triggers enforce active-program count, active employee-seat count (the owner membership is excluded), and monthly QR issue quantity for merchants with active subscriptions. Per-merchant advisory locks serialize capacity-consuming changes. Existing merchants without an assigned subscription are grandfathered until an administrator assigns a plan.
- A paused, expired, or cancelled subscription blocks new capacity-consuming program/member/QR batch creation. It does not delete existing programs, staff, customer points, rewards, or QR history.
- Branch counts, campaigns, customer segments, API access, advanced exports, and priority support remain planned capabilities unless separately implemented. Plan cards label these as planned, not live.

### Validation and limits

A rollback-only authenticated-database-role test created a temporary merchant account, verified the owner membership and initial plan via protected RPCs, exercised upgrade, downgrade, renewal, pause, reactivation, and confirmed a non-Super-Admin request is denied. A further rollback-only capacity test verified that the owner does not consume an employee seat, two employees fit the $9 plan, and a third employee is rejected. All temporary rows were rolled back. No test subscription or merchant row was left behind. CI type-checks the invitation Edge Function and checks the admin UI/RPC wiring. A live invitation email delivery and owner acceptance test still requires a real recipient inbox.

## Secure bulk QR factory

- The platform admin console includes a permission-gated QR factory for active points/stamps programs. Super Admin and the `loyalty.qr.manage` permission can create batches of 1–1,000 codes with a fixed value and required expiry (maximum 365 days).
- Codes contain 128 bits of cryptographically random entropy. SHA-256 digests are unique within the QR factory and checked against existing loyalty token digests before insertion.
- Printable code material is stored only as AES-256 encrypted ciphertext under a private database-held key; plaintext is returned only during initial creation or an authorized, audited reprint. Private tables and key are not granted to API roles.
- Reprinting returns the original codes and never creates new ones. Revocation changes every still-issued code in the batch to revoked. Consumed codes remain consumed.
- `claim_admin_qr_code` is the customer-side atomic claim RPC: it locks the code row, validates batch/merchant/program/expiry, creates or locks the customer's loyalty account, credits the fixed points/stamps amount, writes ledger and audit records, and marks the code consumed in one transaction.
- The admin UI renders QR labels in a print-ready browser page; the browser print dialog can save the layout as PDF. The admin UI and database feature are implemented, but the Flutter customer scan/claim screen still requires integration and device-level end-to-end testing before customer redemption is live.


## QR factory preview deployment

- A preview build of the QR factory was deployed to Vercel for review: `https://wathaq-platform-admin-3vfpj07kz-novexa14.vercel.app`.
- The existing production alias was intentionally left unchanged until the preview is checked in a real browser session.

- The QR factory loads eligible programs through its own `loyalty.qr.manage`-scoped RPC; it does not require the operator to also have the broader `merchants.read` permission.

- Claim and revoke routines acquire locks in the same batch-then-code order, avoiding a claim/revoke lock inversion under concurrent use.

- When there are no active merchants with active, in-window loyalty programs, the factory shows an explicit empty-state message and disables batch creation.


## Super Admin platform merchant creation

- The platform console exposes a dedicated “Create merchant” view to Super Admin only. Ordinary platform operators cannot see or open the view, and the database RPC independently enforces `private.is_platform_admin()`.
- Creation requires an existing WATHAQ auth user as owner; the console selects from the restricted user-profile directory. It never creates auth identities or passwords.
- New merchants are always created with `pending` status. Name, slug, ISO alpha-2 country code, timezone, owner existence, and slug uniqueness are validated server-side.
- The existing `merchant_owner_membership` trigger creates the owner's merchant membership atomically. The RPC writes a `platform.merchant_created` audit event in the same transaction.
- The public RPC is SECURITY INVOKER; privileged insert logic is isolated in a private SECURITY DEFINER function with an empty search_path, authenticated-user check, and Super Admin check. Direct execution of the private function is revoked from API roles.
- Verified on WATHAQ-CORE: a rollback-only test under the authenticated database role created a pending merchant, confirmed the automatic owner membership and audit event, then rolled back. A second authenticated-role test confirmed a non-Super-Admin receives insufficient privilege. No test merchant remains.

- Preview deployment for this feature is READY at https://wathaq-platform-admin-4ldsrhcks-novexa14.vercel.app (commit f0cb21f). The production alias remains unchanged. A live browser sign-in and form submission check is still pending.
- GitHub Actions validation passed: https://github.com/asdzko2023-pixel/Wathaq/actions/runs/45277836569.
- Owner selection now includes a server-side search by profile name or UUID to work within the profile RPC's 100-row page limit.
