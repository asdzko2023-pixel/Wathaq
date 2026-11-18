# Merchant Dashboard v0 — REPORT

## Summary

Implemented a responsive merchant console under `app/merchant/` strictly limited to the RLS and column grants described in the task.

### Files

| File | Role |
|------|------|
| `index.html` | Shell, RTL Arabic layout, responsive CSS (sidebar ≥1024px, bottom nav + drawer on mobile) |
| `merchant.mjs` | Hash router, data access, views, form guards |
| `test/smoke.mjs` | Smoke tests with stubbed Supabase client |
| `REPORT.md` | This report |

### Routes

- `#/register-store` — shown when owner has no merchants
- `#/overview` — KPIs + approval status + pending banner
- `#/program` — list / create / edit programs & rewards
- `#/operations` — transactions table (cards on mobile), filters, pagination
- `#/customers` — read-only masked cards
- `#/subscription` — subscriptions + active plans (RLS), manual renewal note
- `#/settings` — update allowed merchant columns only
- `#/staff` — placeholder only (no inserts)

### Allowed writes enforced in code

- **merchants** insert: `owner_id`, `name`, `category`, `description`, `city`, `area`
- **merchants** update: `name`, `category`, `description`, `city`, `area`
- **programs** insert: `merchant_id`, `type`, `name`, `rules`, `status`
- **programs** update: `name`, `rules`, `status`
- **rewards** insert: `program_id`, `merchant_id`, `title`, `cost`, `is_active`
- **rewards** update: `title`, `cost`, `is_active`

Any extra keys passed by the UI are stripped before the client call. No deletes are implemented.

### Program rules

Editable keys: `target`, `earn_text`, `redeem_text`, `per_code`, `max_per_code`.

Before saving a rules change the UI shows:

> تعديل القواعد ينشئ نسخة جديدة من البرنامج وتبقى العمليات السابقة كما هي.

Publishing (`status=active`) is blocked when the program has zero active rewards.

### KPIs (`#/overview`)

| Metric | Definition | Query approach |
|--------|------------|----------------|
| members | count of cards for the merchant | `cards` + `count:exact, head:true` |
| active in 30 days | distinct-ish customer activity via earn txs in last 30d | `transactions` filtered `type=earn` + `created_at >= 30d` |
| earn operations (30d) | count earn txs | same filters |
| redemptions (30d) | count redeem txs | `type=redeem` + 30d |

Pending merchants show a warning banner that customers cannot see the store yet.

### Operations

- Page size 25 via `.range()`
- Filters: type, period
- Customer shown as last 4 chars of `customer_id`
- Note: «سجل العمليات لا يقبل التعديل أو الحذف.»

### Subscription

- No hard-coded prices, no payment buttons
- Empty: «لا توجد باقات مفعّلة بعد.»
- Note: «التجديد يدوي حاليًا. تواصل مع فريق وِثاق.»

### Staff

**Not implemented** (no inserts). UI shows:

> إدارة الموظفين غير متاحة بعد

---

## Requests to Claude

1. **Staff invite backend function**  
   The `staff` / merchant membership table has no way for an owner to look up a user id by phone or email.  
   Please add a secure backend function (Edge Function or RPC) that:
   - Accepts phone and/or email
   - Resolves the target user id (or creates an invite token)
   - Inserts the membership row with the correct role under RLS that only the merchant owner can trigger
   - Optionally sends an SMS/email invite

2. **Distinct active customers (30d)**  
   Current KPI uses a filtered count on `transactions` (type=earn, last 30d). True `COUNT(DISTINCT customer_id)` may need a database view or RPC if the client cannot express it under the current grants.

3. **Program versioning on rules change**  
   The UI warns that changing rules creates a new program version while keeping historical operations. The actual versioning logic (copy program + freeze old rules) should live in the backend so the frontend only updates the allowed columns.

---

## Smoke tests coverage

- Owner with no store → register flow
- Pending status available for banner
- KPI queries use merchant_id, type, and 30-day filters + `count:exact, head:true`
- Program activation guard (no active rewards)
- Rules-change confirmation string present
- Pagination `range()` page size 25
- HTML escaping helpers present; forbidden write columns stripped
- No writes outside allowed tables/columns; no deletes
- Staff unavailable message
- Subscription empty + manual renewal notes
- Operations immutable note
- Register success message «طلبك قيد المراجعة»
- Customer id masking (last 4 chars)

Run:

```bash
node app/merchant/test/smoke.mjs
```
