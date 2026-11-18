# WATHAQ-CORE migration history

The active database was initialized on the dedicated Supabase project `ncfromrlnlotrwkgjenk` with the following ordered migrations:

1. 20261118004500 — wathaq_core_foundation
2. 20261118004702 — atomic_loyalty_operations
3. 20261118004842 — loyalty_permission_hardening
4. 20261118005321 — rls_policy_and_index_tuning
5. 20261118005623 — merchant_state_and_reward_integrity
6. 20261118005644 — token_entropy_and_single_use_guards
7. 20261118005714 — public_catalog_visibility_guards
8. 20261118005851 — platform_merchant_review_controls
9. 20261118005942 — merchant_staff_invitation_and_rbac
10. 20261118010054 — staff_rbac_documentation_and_audit
11. 202611180101xx — merchant_branding_and_reward_storage

The v0.6 SQL migration files and tests were moved to `reference/v0.6/supabase/` so they cannot be accidentally applied to the clean WATHAQ-CORE project. The active SQL history still needs a full source export into version-controlled migration files before using `supabase db push` from a fresh clone. The live migration history is currently authoritative.
