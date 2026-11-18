# WATHAQ-CORE security review

Review date: 2026-11-19  
Project: `WATHAQ-CORE` (`ncfromrlnlotrwkgjenk`)  
Scope: database roles, RLS, security-definer RPCs, token handling, and current advisor findings.

## Verified controls

- All 13 public tables have Row Level Security enabled.
- The authenticated role has no direct UPDATE privilege on loyalty balances, no INSERT/UPDATE privilege on the ledger, and no direct SELECT/INSERT access to one-time tokens or merchant invitations.
- `loyalty_tokens` and `merchant_invites` intentionally have no client RLS policies. With their direct table privileges revoked, the default-deny behavior is intentional.
- Every function in the private schema has anonymous EXECUTE revoked. Authenticated EXECUTE is granted only to:
  - `private.can_confirm_redeem(uuid)`
  - `private.can_issue_earn(uuid)`
  - `private.can_manage_merchant(uuid)`
  - `private.is_merchant_member(uuid)`
  - `private.is_platform_admin()`
- These five private helpers are used by RLS predicates and protected server-side RPC paths. The private schema is not intended to be exposed through the Supabase Data API. Trigger-only helpers have no client EXECUTE grants.
- The nine public RPC entry points are authenticated-only. Their definitions were inspected to verify `auth.uid()` checks and `search_path = ''`; the anonymous role cannot execute them.
- One-time QR tokens store a SHA-256 digest, have expiry timestamps, and are consumed once. Points/stamps ledger updates and reward stock decrement occur inside database transactions.

## Tests run against the live WATHAQ-CORE database

1. `supabase/tests/core_contract_tests.sql` — PASS. Checks RLS coverage, direct table privilege boundaries, private helper grants, and the nine authenticated-only RPCs.
2. `supabase/tests/loyalty_transaction_integration.sql` — PASS. Exercises points and stamps enrolment, earn, redemption, owner staff-list/update permissions, denial of staff team-management, replay rejection, stock decrement, and immutable ledger behavior. Fixtures are rolled back.
3. GitHub Actions PR runs [44409545584](https://github.com/asdzko2023-pixel/Wathaq/actions/runs/44409545584) and [44409545501](https://github.com/asdzko2023-pixel/Wathaq/actions/runs/44409545501) — PASS on the current test head. Current-source build, public-bundle parity, archive safety, design-token contrast, syntax, and reference smoke checks.

## Advisor findings and interpretation

- **2 INFO — RLS enabled with no policies:** `public.loyalty_tokens` and `public.merchant_invites`. This is intentional deny-by-default; the client cannot access these tables directly.
- **9 WARN — authenticated SECURITY DEFINER functions:** these are the nine public RPC entry points required by the application. They are intentionally callable by authenticated users, but are constrained by identity and merchant-permission checks. Anonymous execution is revoked. Keep these functions under review whenever their bodies change.
- **24 INFO — unused indexes:** the clean database currently has no real customers, merchants, or production traffic. Do not remove indexes based only on this early signal; reassess after workload data exists.
- **0 health findings** were returned by the health advisor.

## Not yet proven / production blockers

- SMS provider configuration, OTP deliverability to Yemen, resend/rate-limit behavior, and account recovery on real devices.
- First platform-admin bootstrap using a real, verified phone identity.
- Full UI-to-database tests using real JWTs and separate customer, owner, and staff accounts.
- Concurrent redemption/earn stress tests, load tests, backup/restore drill, independent penetration test, privacy/terms review, and Android device QA.
- Production hosting deployment and public release.

This review is evidence of the checks listed above, not a claim that the system is fully penetration-tested or production-ready.
