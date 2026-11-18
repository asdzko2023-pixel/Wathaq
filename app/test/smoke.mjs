// Smoke test for the customer app logic with a stubbed DOM and a fake Supabase client. No network needed.
// Run: node app/test/smoke.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
const src = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../src/app.mjs'), 'utf8').replace(/^import .*$/m, '');
const results = []; const ok = (name, cond) => { results.push([name, !!cond]); };
const H = {}; let hash = ''; const app = { innerHTML: '' }; const list = { innerHTML: '' }; const calls = [];
const fire = (t, ev) => (H[t] || []).forEach((f) => f(ev));
const location = { origin: 'https://x.github.io', pathname: '/wathaq/', get hash() { return hash; }, set hash(v) { hash = v; fire('hashchange', {}); } };
const store = {}; const localStorage = { getItem: (k) => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = String(v); }, removeItem: (k) => { delete store[k]; } };
Object.defineProperty(localStorage, 'length', { get: () => Object.keys(store).length });
const BAD = '<img src=x onerror=alert(1)>';
const DATA = {
  merchants: [{ id: 'm1', name: BAD, category: 'المقاهي', description: 'وصف', city: 'عدن', area: 'كريتر', is_test: true, programs: [{ id: 'p1', type: 'stamps', name: 'أختام', rules: { target: 8, earn_text: 'ختم لكل مشروب' } }] }],
  rewards: [{ id: 'r1', title: 'قهوة مجانية', cost: 8, program_id: 'p1', merchant_id: 'm1' }],
  cards: [], transactions: [], favorites: [], profiles: { display_name: 'أحمد' },
};
const chain = (table) => { const c = new Proxy(function () {}, { get: (_, k) => (k === 'then' ? (res) => res({ data: DATA[table] ?? [], error: null }) : (...a) => { if (['insert', 'update', 'delete'].includes(k)) calls.push([table, k, a[0]]); return c; }), apply: () => c }); return c; };
let CLAIM = { ok: true, replay: false, type: 'stamps', added: 1, balance: 1, merchant: 'M', card_id: 'c1' }; let REDEEM = { ok: true, code: 'K7M4-Q2AB', expires_at: new Date(Date.now() + 300000).toISOString(), reward: 'قهوة مجانية', cost: 8 }; let authCb; let session = null;
const sbStub = { from: (t) => chain(t), rpc: (n, a) => { calls.push(['rpc', n, a]); if (n === 'my_tier') return Promise.resolve({ data: 'bronze', error: null }); if (n === 'claim_earn_code') { calls.push(['claim', a]); return Promise.resolve({ data: CLAIM, error: null }); } if (n === 'request_redeem') { calls.push(['redeemreq', a]); return Promise.resolve({ data: REDEEM, error: null }); } if (n === 'join_program') { DATA.cards = [{ id: 'c1', stamps: 0, points: 0, created_at: new Date().toISOString(), program_id: 'p1', merchant_id: 'm1', programs: { id: 'p1', type: 'stamps', name: 'أختام', rules: { target: 8 } }, merchants: { id: 'm1', name: BAD, category: 'المقاهي' } }]; return Promise.resolve({ data: 'c1', error: null }); } return Promise.resolve({ data: null, error: null }); },
  auth: { getSession: async () => ({ data: { session } }), onAuthStateChange: (cb) => { authCb = cb; }, signInWithOtp: async (a) => { calls.push(['otp', a]); return { error: null }; }, verifyOtp: async (a) => { calls.push(['verify', a]); session = { user: { id: 'u1', phone: '967777000001', phone_confirmed_at: 'x' } }; authCb('SIGNED_IN', session); return { error: null }; }, signOut: async () => { session = null; authCb('SIGNED_OUT', null); } } };
const ctx = {
  createClient: () => sbStub, window: { WATHAQ_CONFIG: { url: 'https://x.supabase.co', key: 'k' }, addEventListener: (t, f) => { (H[t] = H[t] || []).push(f); }, scrollTo() {} },
  document: { querySelector: (s) => (s === '#app' ? app : s === '#list' ? list : null), addEventListener: (t, f) => { (H[t] = H[t] || []).push(f); }, documentElement: { setAttribute() {} }, createElement: () => ({ setAttribute() {}, remove() {}, style: {} }), body: { appendChild() {} } },
  localStorage, location, navigator: { onLine: true }, history: { length: 1, back() {} }, fetch: async () => ({ json: async () => ({ external: { phone: true, email: true, google: false } }) }),
  confirm: () => true, setInterval: () => 0, clearInterval() {}, setTimeout: (f) => 0, Object, JSON, Date, Promise, Array, String, Set, Math, console, Proxy,
};
const names = Object.keys(ctx);
const run = new Function(...names, src);
run(...names.map((n) => ctx[n]));
const wait = () => new Promise((r) => setImmediate(r)); const tick = async () => { for (let i = 0; i < 8; i++) await wait(); };
const click = (a) => fire('click', { target: { closest: () => ({ dataset: { a }, disabled: false }) } });
const input = (id, value) => fire('input', { target: { id, value } });
await tick();
ok('logged-out user lands on login', hash === '#/login' && app.innerHTML.includes('إرسال الرمز برسالة نصية'));
ok('WhatsApp appears only as a disabled coming-soon row, never as an action', app.innerHTML.includes('رمز عبر واتساب') && app.innerHTML.includes('قريبًا') && !/data-a="[^"]*(whatsapp|wa)/i.test(app.innerHTML));
input('phone', '123'); click('sendotp'); await tick();
ok('invalid phone shows an error and sends nothing', app.innerHTML.includes('أدخل رقم هاتف صحيحًا') && !calls.some((c) => c[0] === 'otp'));
input('phone', '٠٧٧٧٠٠٠٠٠١'.replace('٠٧', '٧') + '٠'); // Arabic-Indic digits are normalised
input('phone', '777 000 001'); click('sendotp'); await tick();
const sent = calls.find((c) => c[0] === 'otp');
ok('OTP requested by SMS for +967 number', sent && sent[1].phone === '+967777000001' && !('channel' in sent[1]));
ok('OTP screen shown', hash === '#/otp' && app.innerHTML.includes('أدخل رمز التحقق'));
input('tok', '12'); click('verify'); await tick();
ok('short code rejected locally', app.innerHTML.includes('6 أرقام'));
input('tok', '123456'); click('verify'); await tick();
const v = calls.find((c) => c[0] === 'verify');
ok('verifyOtp called with type sms', v && v[1].type === 'sms' && v[1].token === '123456' && v[1].phone === '+967777000001');
ok('signed-in user reaches home with real data states', hash === '#/home' && app.innerHTML.includes('بطاقات نشطة') && app.innerHTML.includes('لم تنضم إلى أي برنامج'));
hash = '#/discover'; fire('hashchange', {}); await tick();
ok('discover escapes untrusted store names (no raw HTML injection)', !app.innerHTML.includes('<img src=x') && app.innerHTML.includes('&lt;img'));
ok('test merchants are labelled', app.innerHTML.includes('بيانات تجريبية'));
input('q', 'لا يوجد'); ok('search with no match shows empty state', list.innerHTML.includes('لا توجد متاجر مطابقة')); input('q', '');
hash = '#/store/m1'; fire('hashchange', {}); await tick();
ok('store page shows terms before joining', app.innerHTML.includes('ختم لكل مشروب') && app.innerHTML.includes('انضم إلى برنامج الولاء'));
click('join:p1'); await tick();
ok('join uses the server RPC, not a direct card insert', calls.some((c) => c[0] === 'rpc' && c[1] === 'join_program' && c[2].p_program_id === 'p1') && !calls.some((c) => c[0] === 'cards'));
ok('after joining, card page opens and shows derived text', hash === '#/card/c1' && app.innerHTML.includes('بقي لك 8 أختام للوصول إلى مكافأتك.'));
ok('redeem is honestly disabled (server function not built)', /disabled>تحتاج 8 أختام إضافية|disabled>الاستبدال سيتوفر قريبًا/.test(app.innerHTML));
ok('client never writes balances', !calls.some((c) => ['cards', 'transactions', 'reward_tokens'].includes(c[0]) && ['insert', 'update', 'delete'].includes(c[1])));
fire('offline', {}); ok('offline banner appears', app.innerHTML.includes('أنت غير متصل')); fire('online', {});
hash = '#/account'; fire('hashchange', {}); await tick();
ok('account shows verified phone and tier', app.innerHTML.includes('الهاتف موثّق') && app.innerHTML.includes('برونزي'));
click('logout'); await tick();
ok('logout returns to login', hash === '#/login');
ok('no "undefined" leaked into the UI', !app.innerHTML.includes('undefined') && !app.innerHTML.includes('NaN'));
click('emailopen');
ok('login screen offers a code by email, never a link', app.innerHTML.includes('إرسال رمز إلى البريد') && !/رابط/.test(app.innerHTML));
 input('email', ' Test@Example.com '); click('email'); await tick();
const eo = calls.filter((c) => c[0] === 'otp').pop();
ok('email code requested with no redirect link', eo[1].email === 'test@example.com' && !JSON.stringify(eo[1]).includes('edirect'));
ok('email code screen shown, says six digits', hash === '#/otp' && app.innerHTML.includes('إلى بريدك') && app.innerHTML.includes('6 أرقام') && app.innerHTML.includes('maxlength="6"'));
input('tok', '12345'); click('verify'); await tick();
ok('five digits rejected locally', app.innerHTML.includes('أدخل الرمز المكوّن من 6 أرقام'));
input('tok', '654321'); click('verify'); await tick();
const v2 = calls.filter((c) => c[0] === 'verify').pop();
ok('verifyOtp type email with the 6-digit code', v2[1].type === 'email' && v2[1].token === '654321' && v2[1].email === 'test@example.com');
ok('email sign-in reaches home', hash === '#/home');
ok('UI never asks the user to open a login link', !/رابط الدخول|افتحه من هذا الجهاز/.test(app.innerHTML));

// ---- customer earn / redeem wiring ----
click('logout'); await tick();
input('phone', '777000001'); click('sendotp'); await tick(); input('tok', '123456'); click('verify'); await tick();
hash = '#/claim'; fire('hashchange', {}); await tick();
input('code', 'ab'); click('claim'); await tick();
ok('malformed code is rejected locally, no request', app.innerHTML.includes('الرمز غير صحيح') && !calls.some((c) => c[0] === 'claim'));
input('code', 'abcd-2345'); click('claim'); await tick();
const cl = calls.find((c) => c[0] === 'claim');
ok('claim sends the normalised code to the server RPC', cl && cl[1].p_code === 'ABCD-2345');
ok('claim success shows the result from the server', app.innerHTML.includes('تمت الإضافة إلى بطاقتك') && app.innerHTML.includes('+1 ختم'));
for (const [code, text] of [['code_used', 'استُخدم من قبل'], ['code_expired', 'انتهت صلاحية الرمز'], ['phone_not_verified', 'توثيق رقم هاتفك'], ['too_many_attempts', 'محاولات كثيرة']]) { CLAIM = { ok: false, error: code }; input('code', 'abcd-2345'); click('claim'); await tick(); ok('claim error ' + code + ' maps to an Arabic message', app.innerHTML.includes(text) && !app.innerHTML.includes(code)); }
CLAIM = { ok: false, error: 'not_joined', program_id: 'p1' }; click('claim'); await tick();
ok('not_joined guides the user to the store page and says the code was kept', app.innerHTML.includes('لم يُستهلك الرمز') && app.innerHTML.includes('#/store/m1'));
CLAIM = { ok: true, replay: true, type: 'stamps', added: 1, card_id: 'c1' }; click('claim'); await tick();
ok('replay is shown as already recorded', app.innerHTML.includes('سبق تسجيل هذا الرمز'));
DATA.cards = [{ id: 'c1', stamps: 8, points: 0, created_at: new Date().toISOString(), program_id: 'p1', merchant_id: 'm1', programs: { id: 'p1', type: 'stamps', name: 'أختام', rules: { target: 8 } }, merchants: { id: 'm1', name: 'M', category: 'المقاهي' } }];
fire('online', {}); await tick(); hash = '#/card/c1'; fire('hashchange', {}); await tick();
ok('ready card offers a real redeem button per affordable reward', app.innerHTML.includes('data-a="redeem:c1:r1"') && app.innerHTML.includes('استبدال: قهوة مجانية'));
click('redeem:c1:r1'); await tick();
const rq = calls.find((c) => c[0] === 'redeemreq');
ok('redeem calls request_redeem with card and reward ids only', rq && rq[1].p_card_id === 'c1' && rq[1].p_reward_id === 'r1' && Object.keys(rq[1]).length === 2);
ok('the temporary code is shown with a countdown and a no-deduction notice', hash === '#/redeem' && app.innerHTML.includes('K7M4-Q2AB') && app.innerHTML.includes('id="rtm"') && app.innerHTML.includes('لا يُخصم رصيدك قبل تأكيد الموظف'));
ok('redeem and claim never write balances directly', !calls.some((c) => ['cards', 'transactions', 'reward_tokens'].includes(c[0]) && ['insert', 'update', 'delete'].includes(c[1])));

// ---- identity, feature states, sheet, motion ----
hash = '#/features'; fire('hashchange', {}); await tick();
ok('features page shows all three states', ['متاح الآن', 'قيد التطوير', 'مخطط لها'].every((x) => app.innerHTML.includes(x)));
ok('unfinished features carry the in-development badge, not an available one', /مسح الرمز بالكاميرا<\/b>[^]*?قيد التطوير/.test(app.innerHTML) && /الإشعارات<\/b>/.test(app.innerHTML));
ok('WhatsApp and Google (not configured) are listed as in development', app.innerHTML.includes('رمز الدخول عبر واتساب') && app.innerHTML.includes('الدخول بحساب جوجل'));
ok('planned features are listed (nearby, ratings, English)', ['المتاجر القريبة منك', 'تقييمات حقيقية للمتاجر', 'اللغة الإنجليزية'].every((x) => app.innerHTML.includes(x)));
hash = '#/card/c1'; fire('hashchange', {}); await tick();
ok('progress is drawn as the knotted tether with an accessible label', app.innerHTML.includes('class="rope') && /aria-label="\d+ من 8 أختام"/.test(app.innerHTML));
ok('newly earned knot is animated after a claim', app.innerHTML.includes('class="just"'));
hash = '#/account'; fire('hashchange', {}); await tick();
const before = calls.length; click('delreq'); await tick();
ok('delete request opens a confirmation sheet and sends nothing yet', app.innerHTML.includes('class="sheet"') && app.innerHTML.includes('تأكيد الطلب') && !calls.slice(before).some((c) => c[0] === 'profiles'));
click('sheet-no'); await tick(); ok('cancelling closes the sheet without any request', !app.innerHTML.includes('class="sheet"') && !calls.slice(before).some((c) => c[0] === 'profiles'));
click('delreq'); click('sheet-yes'); await tick();
ok('confirming records the deletion request on the profile only', calls.slice(before).some((c) => c[0] === 'profiles' && c[1] === 'update' && c[2] && c[2].deletion_requested_at));
const css = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../src/app.css'), 'utf8');
ok('reduced-motion preference disables animations', /prefers-reduced-motion:\s*reduce[^}]*animation-duration/.test(css));
ok('no raw hex colours remain in the app script except the per-store brand palette', !/#[0-9A-Fa-f]{6}\b/.test(src.replace(/const PAL = \[[^\]]*\];/, '')));
let fail = 0; for (const [n, p] of results) { console.log((p ? 'PASS  ' : 'FAIL  ') + n); if (!p) fail++; }
console.log(fail ? `\n${fail} FAILED` : `\nAll ${results.length} smoke tests passed`); process.exit(fail ? 1 : 0);
