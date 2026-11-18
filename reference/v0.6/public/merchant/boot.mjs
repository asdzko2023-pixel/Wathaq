// Merchant console bootstrap: Supabase client + 6-digit-code sign-in gate, then starts merchant.mjs.
// merchant.mjs (screens and data) receives the authenticated client through setClient().
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';
const CFG = window.WATHAQ_CONFIG || {};
window.__MERCHANT_NO_AUTO_INIT = true;
const loadModule = window.__MERCHANT_LOADER || (() => import('./merchant.mjs'));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const sb = CFG.url && CFG.key ? createClient(CFG.url, CFG.key, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: false } }) : null;
const S = { step: 'start', chan: 'phone', phone: '', email: '', tok: '', err: '', busy: false, cfg: { phone: true, email: false }, emailOpen: false, started: false };
const IN = 'width:100%;min-height:48px;padding:0 16px;border:1px solid var(--border,#B8B2A3);border-radius:12px;font:inherit;background:var(--surface,#fff);color:inherit;box-sizing:border-box';
const BTN = 'width:100%;min-height:48px;border:0;border-radius:12px;font:inherit;font-weight:700;cursor:pointer;background:var(--primary,#C99A3E);color:#0B0B0D';
const GHOST = 'min-height:44px;border:0;background:none;font:inherit;color:var(--primary-hover,#7A5A12);cursor:pointer;text-decoration:underline';
function normPhone(v) { v = String(v).replace(/[\s\-()]/g, '').replace(/[٠-٩]/g, (d) => '٠١٢٣٤٥٦٧٨٩'.indexOf(d)); if (v.startsWith('+')) return /^\+\d{8,15}$/.test(v) ? v : null; v = v.replace(/^00/, ''); if (v.startsWith('967')) v = v.slice(3); v = v.replace(/^0/, ''); return /^7\d{8}$/.test(v) ? '+967' + v : null; }
const AERR = (e) => { const m = ((e && e.message) || '').toLowerCase(); if (!navigator.onLine || m.includes('fetch')) return 'تعذّر الاتصال. تحقق من الإنترنت ثم حاول مجددًا.'; if ((e && e.status) === 429 || m.includes('rate') || m.includes('seconds')) return 'تم إرسال طلبات كثيرة. انتظر قليلًا ثم حاول مجددًا.'; if (m.includes('expired') || m.includes('invalid')) return 'الرمز غير صحيح أو انتهت صلاحيته.'; if (m.includes('provider') || m.includes('unsupported')) return 'طريقة الدخول هذه غير مفعّلة بعد.'; return 'تعذّر إتمام العملية. حاول مرة أخرى.'; };
function gate() {
  let g = document.getElementById('gate');
  if (!g) { g = document.createElement('div'); g.id = 'gate'; g.style.cssText = 'position:fixed;inset:0;z-index:100;background:var(--bg,#FBF8F1);color:var(--text,#202024);display:grid;place-items:center;padding:16px;font-family:var(--font,inherit)'; document.body.appendChild(g); g.addEventListener('click', onClick); g.addEventListener('input', onInput); }
  return g;
}
function render() {
  if (!sb) { gate().innerHTML = '<div style="max-width:380px">إعدادات الاتصال (config.js) غير مكتملة.</div>'; return; }
  const err = S.err ? `<div role="alert" style="color:var(--danger,#B42318);font-size:14px;margin:8px 0">${esc(S.err)}</div>` : '';
  const busy = S.busy ? ' aria-busy="true" disabled' : '';
  let body;
  if (S.step === 'otp') {
    body = `<h1 style="font-size:24px;margin:0 0 8px">أدخل رمز التحقق</h1><p style="color:var(--text-muted,#62626B);margin:0 0 16px">أرسلنا رمزًا من 6 أرقام ${S.chan === 'email' ? 'إلى بريدك الإلكتروني' : 'برسالة نصية إلى هاتفك'}.</p><input id="g-tok" style="${IN};text-align:center;font-size:24px;letter-spacing:8px" dir="ltr" inputmode="numeric" autocomplete="one-time-code" maxlength="6" value="${esc(S.tok)}" aria-label="رمز التحقق">${err}<button style="${BTN};margin-top:12px" data-a="verify"${busy}>تحقق</button><div style="text-align:center;margin-top:8px"><button style="${GHOST}" data-a="back">تغيير الرقم أو البريد</button></div>`;
  } else {
    body = `<h1 style="font-size:24px;margin:0 0 8px">لوحة التاجر</h1><p style="color:var(--text-muted,#62626B);margin:0 0 16px">سجّل دخولك برمز يصلك على هاتفك${S.cfg.email ? ' أو بريدك' : ''}.</p>` +
      (S.cfg.phone ? `<label style="display:block;margin-bottom:12px"><span style="display:block;font-size:14px;margin-bottom:4px">رقم الهاتف</span><div style="display:flex;gap:8px"><span style="${IN};width:84px;display:grid;place-items:center" dir="ltr">+967</span><input id="g-phone" style="${IN};flex:1" dir="ltr" inputmode="tel" placeholder="7XX XXX XXX" value="${esc(S.phone)}"></div></label><button style="${BTN}" data-a="sendphone"${busy}>إرسال الرمز برسالة نصية</button>` : '') +
      (S.cfg.email ? (S.emailOpen ? `<label style="display:block;margin:16px 0 8px"><span style="display:block;font-size:14px;margin-bottom:4px">البريد الإلكتروني</span><input id="g-email" style="${IN}" dir="ltr" type="email" autocomplete="email" value="${esc(S.email)}"></label><button style="${BTN}" data-a="sendemail"${busy}>إرسال رمز إلى البريد</button>` : `<div style="text-align:center;margin-top:12px"><button style="${GHOST}" data-a="emailopen">الدخول بالبريد الإلكتروني</button></div>`) : '') + err;
  }
  gate().innerHTML = `<div style="width:100%;max-width:380px;background:var(--surface,#fff);border:1px solid var(--border,#E8E5DC);border-radius:16px;padding:24px">${body}</div>`;
}
function onInput(e) { const id = e.target.id; if (id === 'g-phone') S.phone = e.target.value; else if (id === 'g-email') S.email = e.target.value; else if (id === 'g-tok') S.tok = e.target.value; }
async function send(args, chan) {
  S.err = ''; S.busy = true; render();
  const { error } = await sb.auth.signInWithOtp(args);
  S.busy = false; if (error) { S.err = AERR(error); render(); return; }
  S.chan = chan; S.step = 'otp'; S.tok = ''; render();
}
async function onClick(e) {
  const t = e.target.closest('[data-a]'); if (!t || S.busy) return; const a = t.dataset.a;
  if (a === 'emailopen') { S.emailOpen = true; return render(); }
  if (a === 'back') { S.step = 'start'; S.err = ''; return render(); }
  if (a === 'sendphone') { const p = normPhone(S.phone); if (!p) { S.err = 'أدخل رقم هاتف صحيحًا مكوّنًا من 9 أرقام يبدأ بـ 7.'; return render(); } S.phone = p; return send({ phone: p }, 'phone'); }
  if (a === 'sendemail') { const em = S.email.trim().toLowerCase(); if (!/^\S+@\S+\.\S+$/.test(em)) { S.err = 'أدخل بريدًا إلكترونيًا صحيحًا.'; return render(); } S.email = em; return send({ email: em, options: { shouldCreateUser: true } }, 'email'); }
  if (a === 'verify') {
    const tok = S.tok.replace(/\D/g, ''); if (!/^\d{6}$/.test(tok)) { S.err = 'أدخل الرمز المكوّن من 6 أرقام.'; return render(); }
    S.err = ''; S.busy = true; render();
    const args = S.chan === 'email' ? { email: S.email, token: tok, type: 'email' } : { phone: S.phone, token: tok, type: 'sms' };
    const { error } = await sb.auth.verifyOtp(args); S.busy = false;
    if (error) { S.err = AERR(error); S.tok = ''; render(); }
  }
}
async function start() {
  if (S.started) return; S.started = true;
  const g = document.getElementById('gate'); if (g) g.remove();
  const out = document.createElement('button'); out.textContent = 'تسجيل الخروج'; out.setAttribute('aria-label', 'تسجيل الخروج');
  out.style.cssText = 'position:fixed;bottom:12px;inset-inline-start:12px;z-index:50;min-height:36px;padding:0 12px;border:1px solid var(--border,#E8E5DC);border-radius:999px;background:var(--surface,#fff);color:inherit;font:inherit;font-size:13px;cursor:pointer';
  out.addEventListener('click', async () => { await sb.auth.signOut(); });
  document.body.appendChild(out);
  const m = await loadModule(); m.setClient(sb); await m.init();
}
async function boot() {
  if (!sb) return render();
  try { const r = await fetch(CFG.url + '/auth/v1/settings', { headers: { apikey: CFG.key } }); const x = ((await r.json()).external) || {}; S.cfg = { phone: !!x.phone, email: !!x.email }; } catch { /* keep defaults */ }
  sb.auth.onAuthStateChange((ev) => { if (ev === 'SIGNED_OUT') location.reload(); else if (ev === 'SIGNED_IN') start(); });
  const { data } = await sb.auth.getSession();
  if (data.session) await start(); else render();
}
boot();
