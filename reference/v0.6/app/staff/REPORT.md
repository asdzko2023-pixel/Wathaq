# Staff page — implementation report

## Delivered
- `app/staff/index.html`: Arabic RTL, responsive staff console with all required styles inline and same-origin `../config.js`.
- `app/staff/staff.mjs`: six-digit phone/email OTP login, merchant/program loading, earn-code issuance, redemption confirmation, expiry timer, session-only activity list, and offline state.
- `app/staff/test/smoke.mjs`: deterministic smoke suite with a fake Supabase client and clock.
- `app/build.mjs`: copies the staff page into `public/staff/` so the relative `../config.js` resolves to `public/config.js`.

## Data access and permissions
- Reads only `merchants`, `merchant_staff`, and active `programs` to build the staff program list.
- Owners receive both UI capabilities; staff capabilities are derived from `merchant_staff.permissions`.
- Does not read `transactions`, does not write tables, and does not modify balances.
- The only business-action RPCs called are `issue_earn_code` and `confirm_redeem`. The server remains authoritative for permission checks, code validity, expiry, and balances.
- The activity list is held only in JavaScript memory and is cleared on sign-out.

## Safety and behavior
- All merchant/program/reward text is HTML-escaped before rendering.
- Optional earn amount/reference are sent as `null` when blank.
- The earn code is removed from the DOM when its client-side countdown reaches zero; the timer is display-only.
- Redemption is never automatically retried. Input is reset by re-rendering after every result.
- Error keys map to the exact Arabic messages in the task; unknown errors and network failures use the specified fallback.
- The `confirm_redeem` SQL function's replay response currently omits `reward` and `customer_ref`. The UI therefore shows a generic reward label and omits the customer suffix when the server does not return it; it does not query `transactions` to fill those fields. A backend response enhancement would be needed to display those two values for replay without violating the no-transactions-read rule.

## Verification
Run from repository root:

```sh
node app/staff/test/smoke.mjs
node app/build.mjs
```

The smoke suite covers login gating, active program discovery, earn RPC payload nulls, countdown expiry and code hiding, all specified RPC error keys (for both operations), success and replay, malicious merchant-name escaping, one-request double-click protection, no `transactions` access, and the offline banner.
