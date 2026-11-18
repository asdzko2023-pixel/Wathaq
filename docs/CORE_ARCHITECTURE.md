# WATHAQ Core — Architecture & Security Decisions

## Product surfaces
1. Customer: sign-in, discover active programs, join, view balances and immutable activity, issue short-lived check-in and redemption codes.
2. Merchant: merchant profile, program setup, reward catalogue, customer and performance insights.
3. Staff: permission-scoped earn and redemption confirmation.
4. Platform administration: merchant review, platform configuration, plans, fraud monitoring and audit review.

## Trust boundaries
- Supabase Auth is the identity provider.
- profiles is a presentation profile, not an authorization source.
- Platform roles are stored in platform_admins; never trust user-editable metadata for authorization.
- Merchant membership and permissions live in merchant_members.
- Customer clients cannot write loyalty_accounts, loyalty_ledger, or loyalty_tokens.
- loyalty_tokens deliberately has no client RLS policies or grants; only audited RPCs access it.
- Every points/stamps mutation is a single database transaction: row locks, balance update, immutable ledger insert, token consumption and audit event.
- Tokens are random, one-time, hashed at rest, and expire quickly.
- Earn points are calculated server-side from purchase amount and program conversion rules; the customer cannot set their own earning quantity.
- Redemption validates balance and stock under row locks to prevent double-spend and oversell.
- Program rule changes increment the version; every ledger row records the version used.

## Current security advisor notes
- SECURITY DEFINER RPC warnings are intentional for the nine exposed business and staff-management RPCs. Each checks auth.uid(), uses an empty search_path, verifies ownership or merchant permission, and performs the critical transaction server-side.
- The no-policy RLS notice on loyalty_tokens is intentional: the table is not directly accessible by client roles.
- Re-run Supabase security and performance advisors after every schema change. Review all warnings; do not silence them without a documented reason.

## Known implementation gaps
- Platform admin bootstrap and UI.
- Staff invitation and permission-management RPCs and UI.
- Merchant approval is available in the Super Admin UI; first-admin bootstrap is documented in docs/PLATFORM_BOOTSTRAP.md.
- Program publishing and pause controls are available to merchant managers.
- Staff invitation, phone-bound acceptance, member listing and activation controls are implemented.
- Integration tests using isolated test identities are available in supabase/tests/loyalty_transaction_integration.sql and roll back all fixtures.
- Abuse/rate limiting and operational alerting.
- End-to-end concurrency, load and independent penetration tests.
- Data retention, export and account deletion workflows.
