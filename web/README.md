# WATHAQ Web UI

Arabic-first responsive multi-surface UI. index.html loads styles.css, config.js, and app.js. Uses the Supabase publishable key only. Authentication uses phone OTP.

Customer: joins active programs, reads account balances and ledger, requests short-lived earn and redeem codes.
Merchant: creates a merchant profile, loyalty programs and rewards.
Staff: confirms earn and redeem codes through server RPCs.

This is an early functional shell. Merchant approval, staff onboarding, admin console, image uploads, camera scanning, tests and deployment are still pending. Do not treat it as production-ready.

Additional surfaces now included:
- Merchant managers can invite staff by verified phone number, and staff accept a one-time invite code after phone OTP sign-in.
- Platform administrators can approve/reject merchant applications after their account is explicitly bootstrapped in platform_admins (see docs/PLATFORM_BOOTSTRAP.md).
- Merchant logos and reward images use dedicated public-read Storage buckets with manager-only upload/update/delete policies and a 5 MB image limit.
- Phone OTP remains dependent on configuring an SMS provider in Supabase Auth; this has not been configured because provider credentials are not available in the project.
