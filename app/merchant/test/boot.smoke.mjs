// Smoke test for the merchant bootstrap (login gate). Stubbed DOM and Supabase, no network. Run: node app/merchant/test/boot.smoke.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
const src = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../boot.mjs'), 'utf8').replace(/^import .*$/m, '');
const R = []; const ok = (n, c) => R.push([n, !!c]); const calls = []; let authCb; let session = null; let started = null;
const mkEl = () => { const h = {}; return { style: {}, innerHTML: '', textContent: '', setAttribute() {}, addEventListener(t, f) { h[t] = f; }, remove() { this.removed = true; }, h }; };
let gateEl = null; const body = []; 
const sb = { auth: { getSession: async () => ({ data: { session } }), onAuthStateChange: (cb) => { authCb = cb; }, signInWithOtp: async (a) => { calls.push(['otp', a]); return { error: null }; }, verifyOtp: async (a) => { calls.push(['verify', a]); session = { user: { id: 'u' } }; authCb('SIGNED_IN', session); return { error: null }; }, signOut: async () => { calls.push(['signout']); } } };
const ctx = { createClient: () => sb,
  window: { WATHAQ_CONFIG: { url: 'https://x.supabase.co', key: 'k' }, __MERCHANT_LOADER: async () => ({ setClient: (c) => { started = { client: c }; }, init: async () => { started.init = true; } }) },
  document: { getElementById: (id) => (id === 'gate' ? (gateEl && !gateEl.removed ? gateEl : null) : null), createElement: () => mkEl(), body: { appendChild: (e) => { body.push(e); if (!gateEl && e.style) gateEl = body[0]; } } },
  navigator: { onLine: true }, location: { reload() { calls.push(['reload']); } }, fetch: async () => ({ json: async () => ({ external: { phone: true, email: true } }) }), console };
const names = Object.keys(ctx); new Function(...names, src)(...names.map((n) => ctx[n]));
const wait = () => new Promise((r) => setImmediate(r)); const tick = async () => { for (let i = 0; i < 8; i++) await wait(); };
await tick();
const g = () => gateEl.innerHTML; const click = (a) => gateEl.h.click({ target: { closest: () => ({ dataset: { a } }) } }); const inp = (id, value) => gateEl.h.input({ target: { id, value } });
ok('logged-out user sees the login gate, not the console', g().includes('لوحة التاجر') && g().includes('إرسال الرمز برسالة نصية') && !started);
ok('no WhatsApp or magic-link option', !/واتساب|رابط/.test(g()));
inp('g-phone', '12'); click('sendphone'); await tick();
ok('invalid phone rejected locally', g().includes('أدخل رقم هاتف صحيحًا') && !calls.some((c) => c[0] === 'otp'));
inp('g-phone', '777 000 001'); click('sendphone'); await tick();
ok('SMS code requested for +967 number', calls.find((c) => c[0] === 'otp')[1].phone === '+967777000001' && g().includes('أدخل رمز التحقق'));
inp('g-tok', '123'); click('verify'); await tick();
ok('short code rejected locally', g().includes('6 أرقام'));
inp('g-tok', '123456'); click('verify'); await tick();
const v = calls.find((c) => c[0] === 'verify');
ok('verifyOtp uses type sms and the 6-digit code', v[1].type === 'sms' && v[1].token === '123456' && v[1].phone === '+967777000001');
ok('after sign-in the gate is removed and the console starts with the client', gateEl.removed && started && started.client === sb && started.init === true);
ok('a sign-out control is added', body.some((e) => e.textContent === 'تسجيل الخروج'));
let fail = 0; for (const [n, p] of R) { console.log((p ? 'PASS  ' : 'FAIL  ') + n); if (!p) fail++; }
console.log(fail ? `\n${fail} FAILED` : `\nAll ${R.length} boot tests passed`); process.exit(fail ? 1 : 0);
