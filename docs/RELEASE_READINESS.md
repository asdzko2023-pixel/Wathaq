# WATHAQ-CORE release readiness

## Completed in the foundation branch
- Dedicated Supabase project WATHAQ-CORE with 15 applied migrations.
- RLS on all public tables, protected balance/ledger/token/invite writes, explicit default-privilege revocation, and audited merchant state transitions.
- Atomic points and stamps earn/redeem RPCs, one-time token guards, idempotency, reward stock decrement, and staff phone-bound invitations.
- Merchant program publishing, staff activation, customer program discovery/search/favorites, rewards feed, merchant seven-day activity chart, PWA shell, QR generation and camera scanning.
- Merchant branding and reward image storage with restricted write policies.
- Consolidated bootstrap SQL, rollback-safe integration test, core security contract test, and GitHub Actions build artifact.
- Live database verification: core security contract test passed; points/stamps earn-and-redeem integration test passed with replay rejection and rollback-safe fixtures.
- Latest CI run `44408384051` passed JavaScript syntax, public bundle generation/parity, bootstrap/test presence checks, and artifact upload.

## Required before production
1. Configure an SMS provider and verify OTP delivery, resend limits, abuse protection and recovery flows using real devices.
2. Create the first platform administrator using docs/PLATFORM_BOOTSTRAP.md.
3. Run end-to-end authentication tests with real verified phone identities and verify all RLS behavior under actual JWTs.
4. Run multi-session concurrency tests, load tests, backup/restore drill and independent penetration review.
5. Confirm privacy policy, terms, merchant onboarding and operational support processes.
6. Deploy the verified public bundle to the chosen hosting target and complete Android device QA.

## Release policy
Keep `build/wathaq-premium-foundation` isolated from `main` until all production prerequisites are complete. The WATHAQ v0.5/v0.6 archives remain reference-only; do not apply their legacy migrations to WATHAQ-CORE.


## Security review (2026-11-19)
- All 12 public tables have RLS enabled. The two sensitive tables `loyalty_tokens` and `merchant_invites` intentionally have no client policies and no direct client table grants; access is only through authenticated, permission-checked RPCs.
- Private-schema helper functions are not exposed through the Data API. Anonymous execution is revoked for every private function. Authenticated execution is granted only to the five helpers required by RLS and the protected RPC call paths; trigger-only helpers remain non-executable by client roles.
- Nine public RPC entry points remain callable by authenticated users because the app needs them. Each was inspected for `auth.uid()` checks and an empty pinned `search_path`; anonymous execution is revoked. See `docs/SECURITY_REVIEW.md`.
- Supabase Advisor still reports 9 authenticated SECURITY DEFINER RPCs (intentional and manually reviewed), 2 RLS-enabled/no-policy INFO findings (deny-by-default sensitive tables), and 24 unused indexes (new database has no production workload yet). Health advisors returned no findings.
