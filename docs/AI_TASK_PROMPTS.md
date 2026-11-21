# WATHAQ: prompts for parallel work (ChatGPT / Grok)

HOW TO USE
1. Attach `WATHAQ_SOURCE_v0.3.zip` to the chat. 2. Paste the SHARED CONTEXT block, then ONE task block. 3. Ask them to return a zip with only new files + REPORT.md. 4. Do NOT give them any key, dashboard access, or the Supabase secret key. 5. Bring the zip back to Claude for review, tests and merge. Never deploy their output directly.

---
## SHARED CONTEXT (paste first, always)

You are a senior front-end engineer working on WATHAQ (Arabic loyalty-program platform, launching in Aden, Yemen). The attached zip is the source of truth. Read these files BEFORE writing anything: `docs/API_CONTRACTS.md`, `docs/DATA_MODEL.md`, `docs/SECURITY_PLAN.md`, `supabase/migrations/*.sql` (schema, RLS, grants, functions), `app/src/app.mjs` (the customer app: copy its patterns), `app/build.mjs`, `app/test/smoke.mjs`, `packages/design-tokens/tokens.json`, `packages/ui/components.css`, `i18n/ar.json`.

ARCHITECTURE FACTS
- Backend is Supabase (Postgres + Auth). All access control is Row Level Security plus the five RPC functions in API_CONTRACTS.md. The client NEVER writes balances, transactions, reward_tokens, cards.stamps/points.
- Front end is a static PWA: vanilla JavaScript ES modules, no framework, no npm dependencies, no build tools beyond `node app/build.mjs`-style concatenation. Allowed external requests: the Supabase project URL, `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm` (exact pin), Google Fonts.
- Login is by 6-digit code only: phone SMS OTP (`signInWithOtp({phone})` then `verifyOtp({phone,token,type:'sms'})`) or email code (`type:'email'`). NO magic links, NO WhatsApp, NO passwords. Read `authCfg` from `GET {url}/auth/v1/settings` and show only enabled methods (copy the customer app).
- Arabic first, real RTL (logical CSS properties), digits Latin (0-9). Use ONLY design tokens (`var(--color-*)`, `--space-*`, ...) and `w-*` classes from components.css. Min touch target 48px. Every icon button has aria-label. State is never conveyed by color alone (icon + text). Respect prefers-reduced-motion.

HARD RULES (violating any = rejected)
1. Do not modify anything outside the folder named in your task. Never edit `supabase/`, `packages/`, `.github/`, `app/src/`, `app/build.mjs`, `i18n/ar.json`. Need a change there? Write it in REPORT.md under "Requests to Claude".
2. Do not invent tables, columns, RPCs, or permissions. If the schema does not support something, build an honest "not available yet" state and list it in REPORT.md. When unsure, ASK in REPORT.md instead of guessing.
3. Escape every string that comes from the database or user input before inserting into HTML (copy `esc()`), or use textContent. No `innerHTML` with raw data. No `eval`, no inline event-handler attributes.
4. Never log or display OTP codes, tokens, session objects, or raw server/Postgres error messages. Show only the Arabic messages from the mapping tables.
5. Every action button is disabled with `aria-busy="true"` while its request is pending (no double submit). Handle: loading (skeleton), empty, error (with retry), offline (banner), expired session (back to login).
6. No fake numbers in production UI. Any demo data must be labelled "بيانات تجريبية" and live only in tests.
7. No secrets in code. The publishable key lives in `config.js` (`window.WATHAQ_CONFIG = {url, key}`), copy the file shape from `app/config.js`; do not hardcode keys elsewhere. Never use or mention a service_role / secret key.
8. Every user-facing string in Arabic, natural phrasing, respectful tone (use: مزاياك، مكافآتك، برنامج الولاء). Never "خصم رخيص" or "اطلب هديتك".

DELIVERABLES (all tasks)
- A zip containing ONLY your new files under your folder, plus `REPORT.md` with: (a) what works, (b) what is NOT implemented, (c) what you could not test, (d) Requests to Claude, (e) the exact commands you ran and their real output.
- `test/smoke.mjs` in your folder, modelled on `app/test/smoke.mjs` (stubbed DOM + fake Supabase client, no network), runnable with plain `node`. Paste its real output in REPORT.md. Do not claim a test passed unless you ran it.

---
## TASK A: Staff page (suggested for ChatGPT). Folder: `app/staff/`

Goal: a mobile-first page for store staff to (1) issue earn codes and (2) confirm customer redemptions, using ONLY `issue_earn_code` and `confirm_redeem`.

Files: `index.html` (self-contained: inline CSS from tokens+components copied at build time is NOT required; link `../` assets instead is NOT allowed either: inline the CSS you need), `staff.mjs`, `test/smoke.mjs`, `REPORT.md`. Same-origin config via `../config.js`.

Screens (hash routes):
1. Login (same 6-digit flows as the customer app). Header shows the user and a sign-out button.
2. Store/program picker: list programs the user can operate. Source: rows from `merchants` where `owner_id = user.id`, plus `merchant_staff` rows of the user joined to `merchants`; then `programs` with `status='active'` for those merchants. If none: empty state "لا توجد برامج مفعّلة لحسابك. تواصل مع صاحب المتجر."
3. Tab "عملية مؤهلة": program select, optional amount (number input, integer >=1; leave empty to use the server default), optional reference (max 60 chars). Button "إصدار رمز استحقاق" calls `rpc('issue_earn_code',{p_program_id,p_amount,p_reference})` (send null for empty fields). On `ok`: show the code very large (LTR, letter-spaced, `XXXX-XXXX`), a visible countdown computed from `expires_at` vs `Date.now()` (display only; the server is the authority), a "نسخ الرمز" button, and the text "اطلب من العميل إدخال هذا الرمز في تطبيقه قبل انتهاء الوقت." When the countdown ends, replace with "انتهت صلاحية الرمز" and a new-code button. Never keep an expired code visible.
4. Tab "استبدال مكافأة": one input (auto-uppercase, accepts with/without dash, `inputmode="text"`, `autocomplete="off"`), button "تأكيد الاستبدال" calls `rpc('confirm_redeem',{p_code})`. Success card: reward title, "تم الاستبدال بنجاح", deducted amount, `customer_ref` shown as "العميل ••" + 4 chars. If `replay` is true show "تم تأكيد هذا الاستبدال سابقًا" (still success styling, no second action). Clear the input after any result.
5. "هذه الجلسة": in-memory list (not persisted) of the codes issued / redemptions confirmed in this session (time, type, outcome). Staff cannot read the transactions table (RLS), so do not query it.

Error mapping for both RPCs (`{ok:false,error}`), exactly:
forbidden → "ليست لديك صلاحية لهذه العملية." · rate_limited → "طلبات كثيرة. انتظر قليلًا ثم حاول مجددًا." · invalid_amount → "الكمية خارج الحد المسموح." · too_many_attempts → "محاولات كثيرة. حاول لاحقًا." · invalid_code → "الرمز غير صحيح." · code_used → "هذا الرمز استُخدم من قبل." · code_expired → "انتهت صلاحية الرمز." · code_unavailable → "الرمز لم يعد متاحًا. اطلب من العميل رمزًا جديدًا." · wrong_store → "هذا الرمز لا يخص متجرك أو لا تملك صلاحية التأكيد." · insufficient_balance → "رصيد العميل لم يعد كافيًا." · reward_unavailable → "المكافأة غير متاحة حاليًا." · program_unavailable → "البرنامج غير متاح حاليًا." · anything else/network → "تعذّر إتمام العملية. تحقق من الاتصال وحاول مرة أخرى." (do NOT retry a confirm automatically).

Acceptance: smoke tests cover login gating, program list, issuing (payload nulls, countdown expiry hides code), every error code above, confirm success + replay, no HTML injection from a malicious program name, double-click sends one request, offline banner. Page works at 360px width.

---
## TASK B: Merchant dashboard v0 (suggested for Grok). Folder: `app/merchant/`

Goal: a responsive merchant console (sidebar on >=1024px, bottom/drawer nav on mobile) strictly limited to what RLS and column grants allow today. Files: `index.html`, `merchant.mjs`, `test/smoke.mjs`, `REPORT.md`.

Routes and data (use ONLY these):
1. `#/register-store` (shown if the user owns no merchant): insert into `merchants` ONLY the columns `owner_id (= user.id), name, category, description, city, area`. Status is forced to `pending` by RLS. After insert show "طلبك قيد المراجعة". Category picker uses: المطاعم، المقاهي، الحلويات والمخابز، البقالات والسوبرماركت، الملابس، العطور ومستحضرات التجميل، الصالونات، الإلكترونيات، أخرى.
2. `#/overview`: read-only KPIs for the selected owned merchant, each with its definition printed under the number: members = count of `cards` for the merchant; active in 30 days = distinct `customer_id` among `transactions` (type earn) in the last 30 days; earn operations (30d); redemptions (30d, type redeem). Use `select(..., {count:'exact', head:true})` where possible. Show approval status (pending/approved/suspended) and, if pending, a banner explaining that customers cannot see the store yet.
3. `#/program`: list/create/edit programs and their rewards. Allowed writes only: `programs` insert (merchant_id,type,name,rules,status) and update (name,rules,status); `rewards` insert (program_id,merchant_id,title,cost,is_active) and update (title,cost,is_active). `rules` JSON keys you may edit: `target` (int, stamps goal), `earn_text`, `redeem_text`, `per_code`, `max_per_code`. Before saving a rules change show a confirmation: "تعديل القواعد ينشئ نسخة جديدة من البرنامج وتبقى العمليات السابقة كما هي." Reward status shown ONLY as active/inactive (DB has no draft/expired). Do not allow publishing (status=active) a program with zero active rewards. No deletes.
4. `#/operations`: table (cards on mobile) of `transactions` for the merchant: time, type, amount, reason; filters by type and period; pagination (page size 25, `range()`); customers shown only as the last 4 chars of `customer_id`. No edit/delete controls. Note under the table: "سجل العمليات لا يقبل التعديل أو الحذف."
5. `#/customers`: `cards` for the merchant: masked customer ref, program, balance, created date. Read-only.
6. `#/subscription`: read `subscriptions` for the merchant (may be empty) and `plans` (RLS returns active only; may be empty). If no rows: "لا توجد باقات مفعّلة بعد." No prices hard-coded, no payment buttons. Explain manual renewal: "التجديد يدوي حاليًا. تواصل مع فريق وِثاق."
7. `#/settings`: update `merchants` columns name, category, description, city, area only.
8. `#/staff`: DO NOT implement inserts. Show "إدارة الموظفين غير متاحة بعد" and, in REPORT.md under Requests to Claude, state that a backend function to invite staff by phone/email is needed. (The table has no way for an owner to look up a user id.)

Acceptance: smoke tests cover: owner with no store sees register flow; pending banner; KPI queries use the right filters; program save blocked without rewards; confirmation shown on rules change; pagination ranges; HTML-injection test; no write to any table/column outside the allowed lists (assert on the stubbed client calls).

---
## TASK C: Legal and copy drafts (either AI). Folder: `docs/legal/`

Write in clear Modern Standard Arabic, plain language, for non-lawyers: `privacy-policy.md`, `terms-of-use.md`, `merchant-terms.md`, `data-deletion.md`, plus `copy-review.md` (review of `i18n/ar.json` and the Arabic strings in `app/src/app.mjs`: list unnatural phrasing with suggested replacements; do NOT edit those files).
Facts you must reflect (no more, no less): app collects phone number and/or email (for sign-in only), optional display name, loyalty cards, transactions (stamps/points/redemptions), subscription data for merchants, and technical logs needed for security and abuse prevention. No payments, no wallet, no sale of personal data, no advertising profiling. Merchants see only masked customer references and aggregated activity for their own program. Account deletion: user can file a request (field `profiles.deletion_requested_at`); processing time and retention of transaction records are placeholders written as `[يحدده المالك]`. Customers use the service free; merchants subscribe monthly; loyalty rules are set by each merchant, WATHAQ does not guarantee rewards. Service starts in Aden, Yemen; governing law/jurisdiction placeholder `[يحدده المالك]`.
Start every file with: "مسودة تنتظر مراجعة محامٍ مختص قبل الإطلاق." Do not invent company names, addresses, registration numbers, phone numbers, or legal citations; use `[...]` placeholders and list all placeholders at the end of REPORT.md.

---
## WHAT CLAUDE KEEPS (do not delegate)
Database schema, RLS, server functions and their attack tests; platform-admin backend functions; staff-invite function; wiring the customer app to the new RPCs; security review and merge of everything above; CI workflow; real-device and concurrency testing.
