// WATHAQ customer app v0.1 (test build). Vanilla ES module. Server is the source of truth: this app never writes balances.
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';
const CFG = window.WATHAQ_CONFIG || {};
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const ls = { get(k) { try { return JSON.parse(localStorage.getItem(k)); } catch { return null; } }, set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} }, del(k) { try { localStorage.removeItem(k); } catch {} } };
const sb = CFG.url && CFG.key ? createClient(CFG.url, CFG.key, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } }) : null;
const S = { user: null, authCfg: { phone: true, email: false, google: false }, online: navigator.onLine, stale: false, step: 'phone', chan: 'phone', phone: '', tok: '', email: '', name: '', busy: false, err: '', info: '', cd: 0, q: '', cat: 'الكل', cf: 'all', emailOpen: false, code: '', claimRes: null, rdm: null, anim: true, sheet: null, just: null, d: {}, e: {}, tier: null, theme: ls.get('w-theme') || '' };
const CATS = ['الكل', 'المطاعم', 'المقاهي', 'الحلويات والمخابز', 'البقالات والسوبرماركت', 'الملابس', 'العطور ومستحضرات التجميل', 'الصالونات', 'الإلكترونيات', 'أخرى'];
const I = { home: '<path d="M4 11l8-7 8 7v8a1 1 0 0 1-1 1h-4v-6H9v6H5a1 1 0 0 1-1-1z"/>', compass: '<circle cx="12" cy="12" r="9"/><path d="M15.5 8.5l-2 5-5 2 2-5z"/>', cards: '<rect x="3" y="6" width="18" height="13" rx="3"/><path d="M3 10h18"/>', act: '<path d="M4 6h16M4 12h16M4 18h10"/>', user: '<circle cx="12" cy="8" r="4"/><path d="M4 20c1-4 4-6 8-6s7 2 8 6"/>', check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>', clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>', x: '<circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/>', back: '<path d="M9 6l6 6-6 6"/>', info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>', bell: '<path d="M6 17V11a6 6 0 0 1 12 0v6l2 2H4zM10 21h4"/>', heart: '<path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2 4 4 0 0 1 7 2c0 5.5-7 10-7 10z"/>', pin: '<path d="M12 21s-6-5-6-10a6 6 0 0 1 12 0c0 5-6 10-6 10z"/><circle cx="12" cy="11" r="2"/>', off: '<path d="M3 3l18 18M8.5 16.5a5 5 0 0 1 7 0M5 12.5a10 10 0 0 1 4-2.5"/>', gift: '<rect x="4" y="10" width="16" height="10" rx="2"/><path d="M12 10v10M4 14h16"/>' };
const ic = (n, s = '') => `<svg class="w-ico" viewBox="0 0 24 24" aria-hidden="true" style="${s}">${I[n]}</svg>`;
Object.assign(I, { camera: '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>', globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>', star: '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>', chat: '<path d="M4 5h16v11H9l-5 4z"/>', lock: '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>' });
const BURST = Array.from({ length: 14 }, (_, i) => `<i style="--a:${(i * 360) / 14}deg;--d:${56 + (i % 3) * 16}px"></i>`).join('');
const dia = '<svg viewBox="0 0 24 32" aria-hidden="true"><path d="M12 2l9 14-9 14-9-14z"/></svg>';
const stamps = (n, h, just = []) => {
  const W = 300, pad = 14, y = 22, step = n > 1 ? (W - 2 * pad) / (n - 1) : 0, X = (i) => (n > 1 ? W - pad - i * step : W / 2);
  let o = `<svg class="rope w-num" viewBox="0 0 ${W} 56" role="img" aria-label="${h} من ${n} أختام"><line class="cord" x1="${pad}" y1="${y}" x2="${W - pad}" y2="${y}"/>`;
  if (h > 0 && n > 1) o += `<line class="cord fill" x1="${W - pad}" y1="${y}" x2="${X(Math.min(h, n) - 1)}" y2="${y}"/>`;
  for (let i = 0; i < n; i++) {
    const x = X(i).toFixed(1), last = i === n - 1;
    if (i < h) o += `<g class="${just.includes(i) ? 'just' : ''}"><circle class="k-on" cx="${x}" cy="${y}" r="${last ? 12 : 9}"/><path class="tie" d="M${x - 4} ${y - 3}L${+x + 4} ${y + 3}M${x - 4} ${y + 3}L${+x + 4} ${y - 3}"/></g>`;
    else o += last ? `<circle class="k-g" cx="${x}" cy="${y}" r="12"/><path class="tie" style="stroke:var(--color-accent-strong)" d="M${x - 5} ${y}L${+x + 5} ${y}M${x} ${y - 5}L${x} ${y + 5}"/>` : `<circle class="k-off" cx="${x}" cy="${y}" r="9"/>`;
    o += `<text x="${x}" y="50" text-anchor="middle">${i + 1}</text>`;
  }
  return o + '</svg>';
};
const bd = (k, i, t) => `<span class="w-badge w-badge--${k}">${ic(i)}${t}</span>`;
const pr = (p) => `<div class="w-progress" role="progressbar" aria-valuenow="${p}" aria-valuemin="0" aria-valuemax="100"><i style="--p:${p}%"></i></div>`;
const plu = (n, one, two, few, many) => (n === 1 ? one : n === 2 ? two : n >= 3 && n <= 10 ? `${n} ${few}` : `${n} ${many}`);
const stT = (n) => plu(n, 'ختم واحد', 'ختمان', 'أختام', 'ختمًا');
const ptT = (n) => plu(n, 'نقطة واحدة', 'نقطتان', 'نقاط', 'نقطة');
const PAL = ['#1F5C4D', '#8A5A10', '#7A2E3B', '#2A303A', '#315EA8', '#5B3A8A'];
const col = (id) => PAL[[...String(id)].reduce((a, c) => a + c.charCodeAt(0), 0) % PAL.length];
const logo = (m, s = 44) => `<span class="w-logo" style="--m:${col(m.id)};width:${s}px;height:${s}px">${esc((m.name || '؟')[0])}</span>`;
const fmtD = (iso) => { const d = new Date(iso), t = new Date(), y = new Date(Date.now() - 864e5), same = (a, b) => a.toDateString() === b.toDateString(); return same(d, t) ? 'اليوم' : same(d, y) ? 'أمس' : d.toLocaleDateString('ar-u-nu-latn', { day: 'numeric', month: 'long' }); };
const fmtT = (iso) => new Date(iso).toLocaleTimeString('ar-u-nu-latn', { hour: 'numeric', minute: '2-digit' });
// ---------- business display logic (reads only) ----------
function calc(c, rw) {
  const p = c.programs || {}, R = rw.filter((x) => x.program_id === p.id).sort((a, b) => a.cost - b.cost);
  if (p.type === 'stamps') { const goal = +(p.rules && p.rules.target) || (R[0] && R[0].cost) || 0, have = c.stamps, left = Math.max(goal - have, 0); return { type: 's', goal, have, left, ready: goal > 0 && left === 0, pct: goal ? Math.min(100, Math.round((have / goal) * 100)) : 0, R }; }
  const have = c.points, next = R.find((x) => x.cost > have), aff = R.filter((x) => x.cost <= have), goal = next ? next.cost : (R.length ? R[R.length - 1].cost : 0);
  return { type: 'p', goal, have, left: next ? next.cost - have : 0, ready: aff.length > 0, pct: goal ? Math.min(100, Math.round((have / goal) * 100)) : 0, R, next };
}
const CERR = { phone_not_verified: 'يلزم توثيق رقم هاتفك أولًا. سجّل الدخول برمز الرسالة النصية.', too_many_attempts: 'محاولات كثيرة. حاول لاحقًا.', invalid_code: 'الرمز غير صحيح. تأكد منه وأعد المحاولة.', code_used: 'هذا الرمز استُخدم من قبل.', code_unavailable: 'هذا الرمز لم يعد متاحًا. اطلب رمزًا جديدًا من المتجر.', code_expired: 'انتهت صلاحية الرمز. اطلب رمزًا جديدًا من المتجر.', program_unavailable: 'هذا البرنامج غير متاح حاليًا.', rate_limited: 'طلبات كثيرة. انتظر قليلًا ثم حاول مجددًا.', not_found: 'البطاقة غير موجودة.', reward_unavailable: 'هذه المكافأة غير متاحة حاليًا.', insufficient_balance: 'رصيدك لا يكفي لهذه المكافأة بعد.' };
const cerr = (e) => CERR[e] || 'تعذّر إتمام العملية. تحقق من الاتصال وحاول مرة أخرى.';
const need = (x) => (x.type === 's' ? `بقي لك ${stT(x.left)} للوصول إلى مكافأتك.` : x.next ? `بقي لك ${ptT(x.left)} للمكافأة التالية.` : 'وصلت إلى أعلى مكافأة متاحة في هذا البرنامج.');
// ---------- data ----------
const q = async (p) => { const { data, error } = await p; if (error) throw error; return data; };
async function load(key, fn) { const ck = 'wc:' + S.user.id + ':' + key; try { const v = await fn(); ls.set(ck, v); S.d[key] = v; delete S.e[key]; } catch (e) { const c = ls.get(ck); if (c) { S.d[key] = c; S.stale = true; } else S.e[key] = 1; } }
const qCards = () => q(sb.from('cards').select('id,stamps,points,created_at,program_id,merchant_id,programs(id,type,name,rules),merchants(id,name,category,is_test)').order('created_at', { ascending: false }));
const qTx = () => q(sb.from('transactions').select('id,type,amount,reason,created_at,card_id,cards(merchants(name),programs(type,name))').order('created_at', { ascending: false }).limit(60));
async function loadAll() {
  S.stale = false; S.e = {};
  await Promise.all([
    load('cards', qCards),
    load('stores', () => q(sb.from('merchants').select('id,name,category,description,city,area,is_test,programs(id,type,name,rules)').eq('status', 'approved').order('name'))),
    load('rewards', () => q(sb.from('rewards').select('id,title,cost,program_id,merchant_id').eq('is_active', true).order('cost'))),
    load('tx', qTx),
    load('favs', () => q(sb.from('favorites').select('merchant_id'))),
    load('tier', async () => { const t = await q(sb.rpc('my_tier')); return { v: t }; }),
    load('profile', async () => { const p = await q(sb.from('profiles').select('display_name').eq('id', S.user.id).maybeSingle()); return p || {}; }),
  ]);
  if (S.d.profile) S.name = S.d.profile.display_name || '';
  render();
}
// ---------- UI pieces ----------
const lcard = (c, x) => `<a class="w-lcard${S.anim ? ' w-appear' : ''}" href="#/card/${c.id}" style="--m:${col(c.merchants.id)};text-decoration:none"><div class="w-lcard__head">${logo(c.merchants)}<div style="flex:1"><b>${esc(c.merchants.name)}</b><div class="m">${x.type === 's' ? 'بطاقة أختام' : 'برنامج نقاط'}</div></div><span class="w-num" style="font-weight:700">${x.have} / ${x.goal || '—'}</span></div><div style="margin-top:12px">${x.type === 's' && x.goal && x.goal <= 12 ? stamps(x.goal, x.have) : pr(x.pct)}</div>${x.ready ? '<div style="margin-top:8px">' + bd('success', 'check', 'جاهزة للاستبدال') + '</div>' : ''}</a>`;
const row = (m, t, s, b = '', href = '') => `<${href ? 'a href="' + href + '"' : 'div'} class="ro" style="text-decoration:none;color:inherit">${logo(m, 40)}<div><b>${esc(t)}</b><div class="m">${esc(s)}</div></div>${b}</${href ? 'a' : 'div'}>`;
const skel = () => '<div class="px">' + [[104, 8], [132, 12], [96, 12], [96, 12]].map(([h, m]) => `<div class="w-skel" style="height:${h}px;margin:${m}px 0"></div>`).join('') + '</div>';
const errBox = () => `<div class="px"><div class="w-card w-state">${ic('x', 'width:40px;height:40px;color:var(--color-danger)')}<h3>تعذّر تحميل البيانات</h3><p>تحقق من الإنترنت ثم حاول مجددًا. بياناتك لم تتأثر.</p><button class="w-btn w-btn--secondary" data-a="retry">إعادة المحاولة</button></div></div>`;
const empty = (t, p, b) => `<div class="w-state"><div style="width:220px;margin:0 auto 16px">${stamps(6, 0)}</div><h3>${t}</h3><p>${p}</p>${b || ''}</div>`;
const top = (t, right = '<span style="width:48px"></span>') => `<div class="h"><button class="w-btn w-btn--secondary" aria-label="رجوع" data-a="back" style="width:48px;padding:0">${ic('back')}</button><b>${t}</b>${right}</div>`;
const nav = (a) => `<nav class="w-nav" aria-label="التنقل الرئيسي">${[['home', 'الرئيسية', 'home'], ['discover', 'اكتشف', 'compass'], ['cards', 'بطاقاتي', 'cards'], ['activity', 'نشاطي', 'act'], ['account', 'حسابي', 'user']].map(([r, l, i]) => `<a href="#/${r}"${r === a ? ' aria-current="page"' : ''}>${ic(i)}${l}</a>`).join('')}</nav>`;
const sec = (t, more = '') => `<div class="h2">${t}${more}</div>`;
// ---------- screens ----------
function login() {
  const a = S.authCfg, none = !a.phone && !a.email && !a.google;
  return `<div class="px"><div class="hero" style="text-align:center;padding:28px 20px;margin-top:12px"><img alt="وِثاق" src="./assets/logo.png" style="width:190px;max-width:100%"><p class="m" style="margin:12px 0 0">مزاياك تبدأ من مشترياتك.</p></div><h1 class="h1" style="margin-top:28px">مرحبًا بك في وِثاق</h1><p class="m" style="font-size:16px;margin:8px 0 28px">سجّل دخولك لتتابع بطاقات الولاء والمكافآت في مكان واحد.</p>
  ${a.phone ? `<label class="w-field"><span>رقم الهاتف</span><div style="display:flex;gap:8px"><span class="w-input w-num" style="width:84px;display:grid;place-items:center" dir="ltr">+967</span><input id="phone" class="w-input w-num" dir="ltr" inputmode="tel" autocomplete="tel-national" placeholder="7XX XXX XXX" value="${esc(S.phone)}" style="flex:1" ${S.err ? 'aria-invalid="true"' : ''}></div></label><button class="w-btn w-btn--primary w-btn--block" data-a="sendotp"${S.busy ? ' aria-busy="true"' : ''}>إرسال الرمز برسالة نصية</button><div class="soon-row" aria-disabled="true"><span style="display:flex;align-items:center;gap:8px">${ic('chat')}رمز عبر واتساب</span><span class="soon">${ic('clock')}قريبًا</span></div>` : ''}
  ${!a.google ? '<div class="soon-row" aria-disabled="true"><span style="display:flex;align-items:center;gap:8px">' + ic('globe') + 'الدخول بحساب جوجل</span><span class="soon">' + ic('clock') + 'قريبًا</span></div>' : ''}
  ${S.err ? `<div class="w-error-text" role="alert">${ic('x', 'width:16px;height:16px')}${esc(S.err)}</div>` : ''}
  ${none ? '<div class="note">' + ic('info') + 'طرق تسجيل الدخول غير مفعّلة بعد في بيئة الاختبار.</div>' : ''}
  ${a.email || a.google ? '<div class="m" style="text-align:center;margin:20px 0">أو تابع بـ</div><div style="display:grid;gap:8px">' + (a.google ? '<button class="w-btn w-btn--secondary w-btn--block" data-a="google">المتابعة بحساب جوجل</button>' : '') + (a.email ? (S.emailOpen ? `<label class="w-field"><span>البريد الإلكتروني</span><input id="email" class="w-input" dir="ltr" type="email" autocomplete="email" value="${esc(S.email)}"></label><button class="w-btn w-btn--secondary w-btn--block" data-a="email">إرسال رمز إلى البريد</button>` : '<button class="w-btn w-btn--secondary w-btn--block" data-a="emailopen">البريد الإلكتروني</button>') : '') + '</div>' : ''}
  ${S.info ? `<div class="note" style="margin-top:16px" role="status">${ic('check')}${esc(S.info)}</div>` : ''}
  <p class="m" style="text-align:center;font-size:12px;margin-top:24px">بالمتابعة توافق على شروط الاستخدام وسياسة الخصوصية.</p></div>`;
}
function otp() {
  const em = S.chan === 'email', m = em ? S.email.replace(/^(.).*(@.*)$/, '$1•••$2') : S.phone.replace(/(\+\d{3})(\d)(\d+)(\d{3})/, '$1 $2•• ••• $4');
  return `<div class="px">${top('', '<span></span>').replace('<b></b>', '<b></b>')}<h1 class="h1" style="margin-top:8px">أدخل رمز التحقق</h1><p class="m" style="font-size:16px;margin:8px 0 28px">أرسلنا رمزًا مكوّنًا من 6 أرقام ${em ? 'إلى بريدك' : 'برسالة نصية إلى'} <span class="w-num" dir="ltr">${esc(m)}</span></p>
  <label class="w-field"><span>رمز التحقق</span><input id="tok" class="w-input w-num" dir="ltr" inputmode="numeric" autocomplete="one-time-code" maxlength="6" pattern="[0-9]*" value="${esc(S.tok)}" style="text-align:center;font-size:24px;letter-spacing:8px" ${S.err ? 'aria-invalid="true"' : ''}></label>
  ${S.err ? `<div class="w-error-text" role="alert">${ic('x', 'width:16px;height:16px')}${esc(S.err)}</div>` : ''}
  <button class="w-btn w-btn--primary w-btn--block" style="margin-top:16px" data-a="verify"${S.busy ? ' aria-busy="true"' : ''}>تحقق</button>
  <div style="text-align:center;margin-top:12px"><button class="w-btn w-btn--ghost" id="rs" data-a="resend"${S.cd > 0 ? ' disabled' : ''}>${S.cd > 0 ? 'إعادة الإرسال بعد ' + S.cd + ' ث' : 'إعادة إرسال الرمز'}</button><br><button class="w-btn w-btn--ghost" data-a="changephone">${em ? 'تغيير البريد' : 'تغيير الرقم'}</button></div>
  <div class="note" style="margin-top:20px">${ic('info')}لا تشارك هذا الرمز مع أي شخص.</div></div>`;
}
function home() {
  const c = S.d.cards, rw = S.d.rewards || [];
  if (S.e.cards && !c) return errBox();
  if (!c) return skel();
  const xs = c.map((k) => [k, calc(k, rw)]), ready = xs.filter(([, x]) => x.ready).length, near = xs.filter(([, x]) => !x.ready && x.have > 0).sort((a, b) => b[1].pct - a[1].pct)[0];
  const h = new Date().getHours() < 12 ? 'صباح الخير' : 'مساء الخير';
  return `<div class="px"><div class="h"><div style="display:flex;align-items:center;gap:12px"><img alt="" src="./assets/mark.png" style="height:36px"><div><div class="m">${h}</div><b>${esc(S.name || 'عميل وِثاق')}</b></div></div><a class="w-btn w-btn--secondary" aria-label="الإشعارات" href="#/notifications" style="width:48px;padding:0">${ic('bell')}</a></div>
  <div class="hero" style="margin-top:8px"><div class="m">ملخص برامجك</div><div style="display:flex;gap:24px;margin-top:8px"><div><div class="w-num g" style="font-size:36px;font-weight:600;line-height:1.2">${c.length}</div><div class="m">بطاقات نشطة</div></div><div style="width:1px;background:var(--rope-cord)"></div><div><div class="w-num g" style="font-size:36px;font-weight:600;line-height:1.2">${ready}</div><div class="m">مكافآت جاهزة للاستبدال</div></div></div></div>
  <a class="w-btn w-btn--secondary w-btn--block" style="margin-top:12px" href="#/claim">لدي رمز اكتساب</a>
  ${near ? sec('تابع تقدمك') + lcard(near[0], near[1]) + `<div style="margin-top:8px;font-weight:600;color:var(--color-accent-text)">${need(near[1])}</div>` : ''}
  ${sec('بطاقاتك', c.length ? '<a href="#/cards">عرض الكل</a>' : '')}${c.length ? xs.slice(0, 2).map(([k, x]) => `<div style="margin-bottom:12px">${lcard(k, x)}</div>`).join('') : empty('لم تنضم إلى أي برنامج ولاء بعد.', 'ستظهر بطاقاتك هنا بعد انضمامك إلى برنامج أي متجر مشارك.', '<a class="w-btn w-btn--primary" href="#/discover">اكتشف المتاجر</a>')}
  ${S.d.stores && S.d.stores.length ? sec('اكتشف المتاجر', '<a href="#/discover">المزيد</a>') + S.d.stores.slice(0, 3).map((s) => row(s, s.name, [s.category, s.area].filter(Boolean).join(' · '), '', '#/store/' + s.id)).join('') : ''}
  ${(S.d.tx || []).length ? sec('آخر العمليات', '<a href="#/activity">نشاطي</a>') + S.d.tx.slice(0, 3).map(txRow).join('') : ''}<a class="w-btn w-btn--ghost w-btn--block" style="margin-top:16px" href="#/features">${ic('star')}ما الجديد وقريبًا</a></div>`;
}
function txRow(t) {
  const m = (t.cards && t.cards.merchants) || { id: t.id, name: '—' }, st = t.cards && t.cards.programs && t.cards.programs.type === 'stamps';
  const label = t.type === 'earn' ? (st ? 'ختم جديد' : 'نقاط مضافة') : t.type === 'redeem' ? 'استبدال مكافأة' : 'تعديل على الرصيد';
  const amt = (t.amount > 0 ? '+' : '') + t.amount;
  return row(m, label, `${m.name} · ${fmtD(t.created_at)} ${fmtT(t.created_at)}`, bd('success', 'check', amt + ' · مؤكدة'));
}
function discover() {
  const st = S.d.stores;
  return `<div class="px"><div class="h"><h1 class="h1">اكتشف</h1></div><input id="q" class="w-input" type="search" placeholder="ابحث باسم المتجر أو التصنيف" value="${esc(S.q)}" aria-label="بحث"><div class="chips">${CATS.map((c) => `<button class="chip${S.cat === c ? ' on' : ''}" data-a="cat:${esc(c)}" aria-pressed="${S.cat === c}">${c}</button>`).join('')}</div><div id="list">${list()}</div></div>`;
}
function list() {
  const st = S.d.stores;
  if (S.e.stores && !st) return errBox();
  if (!st) return skel();
  const f = st.filter((s) => (S.cat === 'الكل' || s.category === S.cat) && (s.name + ' ' + (s.description || '') + ' ' + (s.category || '')).includes(S.q));
  if (!f.length) return `<div class="w-state"><h3>لا توجد متاجر مطابقة</h3><p>جرّب اسمًا أو تصنيفًا آخر.</p></div>`;
  const fav = new Set((S.d.favs || []).map((x) => x.merchant_id));
  return f.map((s) => { const p = (s.programs || [])[0]; return `<div class="w-card" style="margin-bottom:12px"><div style="display:flex;gap:12px">${logo(s, 52)}<div style="flex:1"><b>${esc(s.name)}</b><div class="m">${esc(s.description || s.category || '')}</div><div style="margin-top:8px;display:flex;gap:8px;flex-wrap:wrap">${p ? bd('info', 'gift', p.type === 'stamps' ? 'برنامج أختام' : 'برنامج نقاط') : ''}${s.is_test ? bd('warning', 'info', 'بيانات تجريبية') : ''}</div></div><button class="w-btn w-btn--ghost" style="width:48px;padding:0${fav.has(s.id) ? '' : ';color:var(--color-text-muted)'}" aria-label="المفضلة" aria-pressed="${fav.has(s.id)}" data-a="fav:${s.id}">${ic('heart', fav.has(s.id) ? 'fill:currentColor' : '')}</button></div><a class="w-btn w-btn--secondary w-btn--block" style="margin-top:12px;min-height:44px;text-decoration:none" href="#/store/${s.id}">عرض المتجر</a></div>`; }).join('');
}
function store(id) {
  const s = (S.d.stores || []).find((x) => x.id === id);
  if (!S.d.stores) return skel();
  if (!s) return `<div class="px">${top('المتجر')}<div class="w-state"><h3>المتجر غير متاح</h3><p>قد يكون متوقفًا أو غير معتمد.</p><a class="w-btn w-btn--secondary" href="#/discover">العودة للاكتشاف</a></div></div>`;
  const p = (s.programs || [])[0], rw = (S.d.rewards || []).filter((r) => p && r.program_id === p.id), joined = p && (S.d.cards || []).find((c) => c.program_id === p.id), r = (p && p.rules) || {};
  return `<div class="px">${top(esc(s.name))}<div style="display:flex;gap:12px;align-items:center">${logo(s, 64)}<div><h1 class="h1" style="font-size:24px">${esc(s.name)}</h1><div class="m">${esc([s.category, s.area, s.city].filter(Boolean).join(' · '))}</div></div></div>${s.description ? `<p style="margin:12px 0">${esc(s.description)}</p>` : ''}${s.is_test ? '<div style="margin:8px 0">' + bd('warning', 'info', 'بيانات تجريبية') + '</div>' : ''}
  ${p ? `${sec('برنامج الولاء')}<div class="w-card"><b>${esc(p.name)}</b><p class="m" style="margin:4px 0 0">${p.type === 'stamps' ? 'بطاقة أختام' : 'برنامج نقاط'}${r.target ? ' · الهدف ' + stT(+r.target) : ''}</p></div>${sec('الشروط')}<div class="w-card"><div class="ro">${ic('check')}<div>${esc(r.earn_text || 'تُعرض شروط الاكتساب عند إضافتها من المتجر.')}</div></div><div class="ro">${ic('gift')}<div>${esc(r.redeem_text || 'تُعرض شروط الاستبدال عند إضافتها من المتجر.')}</div></div></div>${rw.length ? sec('المكافآت') + `<div class="w-card">${rw.map((x) => `<div class="ro"><div><b>${esc(x.title)}</b><div class="m w-num">${p.type === 'stamps' ? stT(x.cost) : ptT(x.cost)}</div></div></div>`).join('')}</div>` : ''}
  <div style="margin:20px 0">${joined ? `<a class="w-btn w-btn--primary w-btn--block" style="text-decoration:none" href="#/card/${joined.id}">عرض بطاقتك</a>` : `<button class="w-btn w-btn--gold w-btn--block" data-a="join:${p.id}"${S.busy ? ' aria-busy="true"' : ''}>انضم إلى برنامج الولاء</button>`}</div>` : '<div class="note" style="margin-top:16px">' + ic('info') + 'لم يُنشر لهذا المتجر برنامج ولاء بعد.</div>'}</div>`;
}
function cards() {
  const c = S.d.cards, rw = S.d.rewards || [];
  if (S.e.cards && !c) return errBox();
  if (!c) return skel();
  const xs = c.map((k) => [k, calc(k, rw)]).filter(([k, x]) => S.cf === 'all' || (S.cf === 'p' && x.type === 'p') || (S.cf === 's' && x.type === 's') || (S.cf === 'r' && x.ready));
  const F = [['all', 'الكل'], ['p', 'النقاط'], ['s', 'الأختام'], ['r', 'مكافآت متاحة']];
  return `<div class="px"><div class="h"><h1 class="h1">بطاقاتي</h1></div><div class="chips">${F.map(([k, l]) => `<button class="chip${S.cf === k ? ' on' : ''}" data-a="cf:${k}" aria-pressed="${S.cf === k}">${l}</button>`).join('')}</div>${xs.length ? `<div style="display:grid;gap:12px">${xs.map(([k, x]) => lcard(k, x)).join('')}</div>` : empty(c.length ? 'لا توجد بطاقات في هذا الفلتر' : 'لم تنضم إلى أي برنامج ولاء بعد.', c.length ? 'جرّب فلترًا آخر.' : 'ستظهر بطاقاتك هنا بعد انضمامك إلى برنامج أي متجر مشارك.', c.length ? '' : '<a class="w-btn w-btn--primary" href="#/discover">اكتشف المتاجر</a>')}</div>`;
}
function card(id) {
  const k = (S.d.cards || []).find((x) => x.id === id);
  if (!S.d.cards) return skel();
  if (!k) return `<div class="px">${top('البطاقة')}<div class="w-state"><h3>البطاقة غير موجودة</h3><a class="w-btn w-btn--secondary" href="#/cards">بطاقاتي</a></div></div>`;
  const x = calc(k, S.d.rewards || []), r = (k.programs && k.programs.rules) || {}, tx = (S.d.tx || []).filter((t) => t.card_id === id);
  const jn = S.just && S.just.card === k.id && Date.now() - S.just.t < 8000 ? Array.from({ length: S.just.n }, (_, i) => x.have - S.just.n + i) : [];
  const hero = x.type === 's' ? `<div class="w-num" style="text-align:end"><span class="g" style="font-size:48px;font-weight:600;line-height:1">${x.have}</span><span class="m"> / ${x.goal || '—'}</span></div>` : `<div class="w-num" style="text-align:end"><span class="g" style="font-size:48px;font-weight:600;line-height:1">${x.have}</span><span class="m"> نقطة</span></div>`;
  return `<div class="px">${top(x.type === 's' ? 'بطاقة الأختام' : 'بطاقة النقاط')}<div class="hero" style="margin-top:8px"><div style="display:flex;justify-content:space-between;align-items:flex-start"><div><div style="font-size:22px;font-weight:700">${esc(k.merchants.name)}</div><div class="m">${esc(k.programs.name)}</div></div>${hero}</div><div style="margin:20px 0 12px">${x.type === 's' && x.goal && x.goal <= 12 ? stamps(x.goal, x.have, jn) : pr(x.pct)}</div><div style="font-weight:600">${need(x)}</div></div>
  ${sec('شروط البرنامج')}<div class="w-card"><div class="ro">${ic('check')}<div>${esc(r.earn_text || 'تُعرض شروط الاكتساب عند إضافتها من المتجر.')}</div></div><div class="ro">${ic('gift')}<div>${esc(r.redeem_text || 'تُعرض شروط الاستبدال عند إضافتها من المتجر.')}</div></div></div>
  ${x.R.length ? sec('المكافآت') + `<div class="w-card">${x.R.map((w) => `<div class="ro"><div><b>${esc(w.title)}</b><div class="m w-num">${x.type === 's' ? stT(w.cost) : ptT(w.cost)}</div></div>${x.have >= w.cost ? bd('success', 'check', 'مستحقة') : bd('warning', 'clock', 'ينقصك ' + (x.type === 's' ? stT(w.cost - x.have) : ptT(w.cost - x.have)))}</div>`).join('')}</div>` : ''}
  ${sec('سجل البطاقة')}${tx.length ? tx.map(txRow).join('') : '<p class="m">لا توجد عمليات بعد. ستظهر هنا عند تأكيد أول عملية من المتجر.</p>'}
  <div class="w-card" style="margin:20px 0 8px">${x.ready ? x.R.filter((w) => x.have >= w.cost).map((w) => `<button class="w-btn w-btn--primary w-btn--block" style="margin-bottom:8px" data-a="redeem:${esc(k.id)}:${esc(w.id)}"${S.busy ? ' aria-busy="true"' : ''}>استبدال: ${esc(w.title)}</button>`).join('') : `<button class="w-btn w-btn--primary w-btn--block" disabled>تحتاج ${x.type === 's' ? stT(x.left) : ptT(x.left)} إضافية</button>`}<p class="m" style="margin:8px 0 0">يصدر النظام رمزًا مؤقتًا تعرضه لموظف المتجر، ولا يُخصم رصيدك إلا بعد تأكيد الموظف.</p></div></div>`;
}
function activity() {
  const t = S.d.tx;
  if (S.e.tx && !t) return errBox();
  if (!t) return skel();
  const g = {}; t.forEach((x) => { (g[fmtD(x.created_at)] = g[fmtD(x.created_at)] || []).push(x); });
  return `<div class="px"><div class="h"><h1 class="h1">نشاطي</h1></div>${t.length ? Object.entries(g).map(([d, a]) => `<div class="m" style="margin-top:16px">${d}</div>${a.map(txRow).join('')}`).join('') : empty('ستظهر هنا عملياتك ومكافآتك', 'عندما تبدأ باستخدام برامج الولاء.', '<a class="w-btn w-btn--primary" href="#/discover">اكتشف المتاجر</a>')}</div>`;
}
function claim() {
  const r = S.claimRes; let box = '';
  if (r && r.ok) box = `<div class="w-card" style="margin-top:16px;text-align:center">${r.replay ? '' : '<div class="burst" aria-hidden="true">' + BURST + '</div>'}${bd('success', 'check', 'تمت العملية')}<h2 style="margin:12px 0 4px">${r.replay ? 'سبق تسجيل هذا الرمز' : 'تمت الإضافة إلى بطاقتك'}</h2><p class="m">${r.replay ? '' : esc(r.merchant || '') + ' · '}+${esc(r.added)} ${r.type === 'points' ? 'نقطة' : 'ختم'}${r.balance != null ? ' · رصيدك ' + esc(r.balance) : ''}</p><a class="w-btn w-btn--primary" href="#/card/${esc(r.card_id)}">عرض البطاقة</a></div>`;
  else if (r && r.error === 'not_joined') { const st = (S.d.stores || []).find((x) => (x.programs || []).some((p) => p.id === r.program_id)); box = `<div class="note" style="margin-top:16px">${ic('info')}انضم أولًا إلى برنامج هذا المتجر ثم أعد إدخال الرمز. لم يُستهلك الرمز.</div>${st ? `<a class="w-btn w-btn--primary w-btn--block" style="margin-top:12px" href="#/store/${esc(st.id)}">فتح صفحة المتجر</a>` : ''}`; }
  else if (r) box = `<div class="w-error-text" role="alert" style="margin-top:16px">${ic('x', 'width:16px;height:16px')}${esc(cerr(r.error))}</div>`;
  return `<div class="px">${top('إدخال رمز اكتساب')}<p class="m" style="font-size:16px">اطلب الرمز من موظف المتجر بعد عملية مؤهلة، وأدخله قبل انتهاء وقته.</p><label class="w-field"><span>رمز الاكتساب</span><input id="code" class="w-input w-num" dir="ltr" autocapitalize="characters" autocomplete="off" maxlength="9" placeholder="XXXX-XXXX" value="${esc(S.code)}" style="text-align:center;font-size:24px;letter-spacing:4px"></label><button class="w-btn w-btn--primary w-btn--block" data-a="claim"${S.busy ? ' aria-busy="true"' : ''}>تأكيد الرمز</button>${box}</div>`;
}
const mmss = (sec) => Math.floor(sec / 60) + ':' + String(sec % 60).padStart(2, '0');
const leftSec = (r) => Math.max(0, Math.round((new Date(r.expires_at) - Date.now()) / 1000));
function redeem() {
  const r = S.rdm;
  if (!r) return `<div class="px">${top('رمز الاستبدال')}<div class="w-state"><h3>لا يوجد طلب استبدال</h3><a class="w-btn w-btn--secondary" href="#/cards">بطاقاتي</a></div></div>`;
  if (r.done) return `<div class="px">${top('رمز الاستبدال')}<div class="w-state"><div class="burst" aria-hidden="true">${BURST}</div>${ic('check', 'width:48px;height:48px;color:var(--color-success)')}<h3>تم الاستبدال بنجاح</h3><p>${esc(r.reward)}</p><a class="w-btn w-btn--primary" href="#/card/${esc(r.card_id)}">عرض البطاقة</a></div></div>`;
  const left = leftSec(r);
  if (!left) return `<div class="px">${top('رمز الاستبدال')}<div class="w-state"><h3>انتهت صلاحية الرمز</h3><p>لم يُخصم أي شيء من رصيدك.</p><button class="w-btn w-btn--primary" data-a="redeem:${esc(r.card_id)}:${esc(r.reward_id)}">طلب رمز جديد</button></div></div>`;
  return `<div class="px">${top('رمز الاستبدال')}<div class="hero" style="text-align:center;margin-top:8px"><div class="m">${esc(r.reward)}</div><div class="w-num g" style="font-size:40px;font-weight:600;letter-spacing:6px;direction:ltr;margin:16px 0">${esc(r.code)}</div>${bd('warning', 'clock', 'ينتهي خلال <b id="rtm">' + mmss(left) + '</b>')}</div><p class="m" style="text-align:center;margin:20px 8px">أظهر هذا الرمز لموظف المتجر ليؤكد الاستبدال. صالح لمرة واحدة، ولا يُخصم رصيدك قبل تأكيد الموظف.</p></div>`;
}
const FEATS = [
  ['avail', 'lock', 'الدخول برمز من 6 أرقام', 'برسالة نصية أو بريد، بلا كلمة مرور ولا روابط.'],
  ['avail', 'cards', 'بطاقات الولاء والتقدم', 'أختام ونقاط وتقدمك نحو كل مكافأة.'],
  ['avail', 'check', 'إدخال رمز الاكتساب', 'أضف أختامك ونقاطك برمز يقدمه موظف المتجر.'],
  ['avail', 'gift', 'استبدال المكافآت', 'رمز مؤقت يؤكده الموظف، ولا يُخصم رصيدك قبل تأكيده.'],
  ['avail', 'act', 'سجل العمليات', 'كل ما اكتسبته واستبدلته في مكان واحد.'],
  ['avail', 'heart', 'المفضلة واكتشاف المتاجر', 'ابحث وصنّف واحفظ متاجرك المفضلة.'],
  ['avail', 'star', 'مستوى العميل', 'برونزي وفضي وذهبي يرتفع بنشاطك خلال 12 شهرًا.'],
  ['avail', 'off', 'العمل مع الاتصال الضعيف', 'نعرض آخر بيانات محفوظة عند انقطاع الإنترنت.'],
  ['dev', 'camera', 'مسح الرمز بالكاميرا', 'امسح رمز المتجر أو الاكتساب بدل كتابته.'],
  ['dev', 'bell', 'الإشعارات', 'تنبيه عند اقتراب مكافأتك أو تأكيد عملية.'],
  ['dev', 'chat', 'رمز الدخول عبر واتساب', 'حاليًا يصلك الرمز برسالة نصية فقط.'],
  ['dev', 'user', 'ربط رقم الهاتف بحساب البريد', 'وثّق هاتفك لتجمع الأختام إن دخلت بالبريد.'],
  ['dev', 'pin', 'شعار المتجر وغلافه وساعات عمله', 'تفاصيل أغنى لصفحة كل متجر.'],
  ['plan', 'pin', 'المتاجر القريبة منك', 'بموافقتك على الموقع فقط.'],
  ['plan', 'star', 'تقييمات حقيقية للمتاجر', 'تقييمات من عملاء استخدموا البرنامج فعلًا.'],
  ['plan', 'gift', 'العروض', 'مزايا ومكافآت المتاجر في صفحة واحدة.'],
  ['plan', 'star', 'مزايا خاصة بكل مستوى', 'تقدير إضافي من المتاجر لعملائها الأوفياء.'],
  ['plan', 'globe', 'اللغة الإنجليزية', 'واجهة بلغتين دون تغيير طريقة الاستخدام.'],
];
function features() {
  const list = [...FEATS, [S.authCfg.google ? 'avail' : 'dev', 'globe', 'الدخول بحساب جوجل', 'دخول سريع بحسابك على جوجل.']];
  const badge = (k) => (k === 'avail' ? bd('success', 'check', 'متاح') : k === 'dev' ? `<span class="soon">${ic('clock')}قيد التطوير</span>` : `<span class="soon plan">${ic('star')}مخطط</span>`);
  return `<div class="px">${top('ما الجديد وقريبًا')}<p class="m" style="font-size:16px;margin:0">صورة كاملة عن وِثاق: ما يعمل اليوم، وما نعمل عليه، وما نخطط له. لا نعرض ميزة على أنها تعمل قبل أن تكتمل.</p>${[['avail', 'متاح الآن'], ['dev', 'قيد التطوير'], ['plan', 'مخطط لها']].map(([k, t]) => { const f = list.filter((x) => x[0] === k); return `<div class="h2">${t}<span class="m w-num">${f.length}</span></div><div class="w-card" style="padding:4px 16px">${f.map(([, i, ti, d]) => `<div class="feat"><div class="fi">${ic(i)}</div><div><b>${ti}</b><p class="m">${d}</p></div>${badge(k)}</div>`).join('')}</div>`; }).join('')}</div>`;
}
const sheetHtml = () => (S.sheet ? `<div class="sheet-bg" data-a="sheet-no"></div><div class="sheet" role="dialog" aria-modal="true" aria-label="${esc(S.sheet.title)}"><h2 style="margin:0 0 8px;font-size:20px">${esc(S.sheet.title)}</h2><p class="m" style="font-size:16px;margin:0">${esc(S.sheet.body)}</p><div style="display:grid;gap:8px;margin-top:20px"><button class="w-btn ${S.sheet.danger ? 'w-btn--secondary' : 'w-btn--primary'}" data-a="sheet-yes">${esc(S.sheet.ok)}</button><button class="w-btn w-btn--ghost" data-a="sheet-no">إلغاء</button></div></div>` : '');
function notifications() { return `<div class="px">${top('الإشعارات')}<div class="w-state">${ic('bell', 'width:40px;height:40px')}<h3>الإشعارات قيد التطوير</h3><p>ستظهر هنا عند اكتمال الخدمة.</p><a class="w-btn w-btn--secondary" href="#/features">ما الجديد وقريبًا</a></div></div>`; }
function account() {
  const u = S.user, tier = { bronze: 'برونزي', silver: 'فضي', gold: 'ذهبي' }[S.d.tier && S.d.tier.v] || '—', ph = u.phone ? '+' + u.phone.replace(/^\+/, '') : '', verified = !!u.phone_confirmed_at;
  return `<div class="px"><div class="h"><h1 class="h1">حسابي</h1></div><div class="w-card" style="display:flex;gap:12px;align-items:center"><span class="w-logo" style="--m:var(--color-hero);color:var(--color-hero-accent);width:52px;height:52px;font-size:20px">${esc((S.name || 'ع')[0])}</span><div style="flex:1"><b>${esc(S.name || 'عميل وِثاق')}</b><div class="m w-num" dir="ltr" style="text-align:end">${esc(ph || u.email || '')}</div></div>${bd('info', 'check', tier)}</div>
  <div style="margin:12px 0">${verified ? bd('success', 'check', 'الهاتف موثّق') : bd('warning', 'clock', 'الهاتف غير موثّق')}</div>
  <label class="w-field"><span>الاسم المعروض</span><input id="name" class="w-input" value="${esc(S.name)}" maxlength="60"></label><button class="w-btn w-btn--secondary" data-a="savename">حفظ الاسم</button>
  <div class="m" style="margin:20px 0 8px">المظهر</div><div style="display:grid;grid-template-columns:repeat(3,1fr);gap:8px">${[['', 'تلقائي'], ['light', 'فاتح'], ['dark', 'داكن']].map(([v, l]) => `<button class="chip${S.theme === v ? ' on' : ''}" style="justify-content:center;min-height:48px;border-radius:12px" data-a="theme:${v}" aria-pressed="${S.theme === v}">${l}</button>`).join('')}</div>
  <a class="w-card" href="#/features" style="display:flex;align-items:center;gap:12px;margin-top:20px;text-decoration:none;color:inherit">${ic('star', 'color:var(--color-accent-text)')}<div style="flex:1"><b>ما الجديد وقريبًا</b><div class="m">المتاح الآن وما نعمل عليه وما نخطط له</div></div>${ic('back', 'transform:scaleX(-1)')}</a>
  <button class="w-btn w-btn--secondary w-btn--block" style="margin-top:24px" data-a="logout">تسجيل الخروج</button>
  <div style="margin-top:48px;text-align:center"><button class="w-btn w-btn--ghost" style="color:var(--color-danger)" data-a="delreq">طلب حذف الحساب</button><p class="m" style="font-size:12px">نسخة الاختبار 0.6 · بيئة التطوير</p></div></div>`;
}
// ---------- router ----------
const AUTH = ['login', 'otp'];
function parse() { const [r = '', id = ''] = location.hash.replace(/^#\//, '').split('/'); return [r, id]; }
function screen() {
  if (!sb) return '<div class="px"><div class="note" style="margin-top:48px">' + ic('x') + 'إعدادات الاتصال (config.js) غير مكتملة.</div></div>';
  const [r, id] = parse();
  return { login, otp, home, discover, store: () => store(id), cards, card: () => card(id), activity, notifications, account, claim, redeem, features }[r]();
}
function render() {
  if (!sb) { $('#app').innerHTML = screen(); return; }
  let [r] = parse();
  if (!S.user && !AUTH.includes(r)) { location.hash = '#/login'; return; }
  if (S.user && (AUTH.includes(r) || !r)) { location.hash = '#/home'; return; }
  if (!screen.length && false) return;
  const known = ['login', 'otp', 'home', 'discover', 'store', 'cards', 'card', 'activity', 'notifications', 'account', 'claim', 'redeem', 'features'];
  if (!known.includes(r)) { location.hash = S.user ? '#/home' : '#/login'; return; }
  const banner = !S.online ? `<div class="off" role="status">${ic('off')}أنت غير متصل. نعرض آخر بيانات محفوظة.</div>` : S.stale && S.user ? `<div class="off" role="status">${ic('clock')}تعذّر تحديث بعض البيانات. نعرض آخر نسخة محفوظة.</div>` : '';
  const main = ['home', 'discover', 'cards', 'activity', 'account'].includes(r) ? r : r === 'store' ? 'discover' : r === 'card' || r === 'redeem' ? 'cards' : r === 'claim' ? 'home' : r === 'features' ? 'account' : '';
  const html = screen(), pg = S.anim; S.anim = false;
  $('#app').innerHTML = banner + `<main id="main"${pg ? ' class="page-in"' : ''}>${html}</main>` + (S.user && !AUTH.includes(r) ? nav(main) : '') + sheetHtml();
  document.documentElement.setAttribute('data-theme', S.theme);
}
// ---------- actions ----------
const AERR = (e) => { const m = ((e && e.message) || '').toLowerCase(); if (!navigator.onLine || m.includes('fetch')) return 'تعذّر الاتصال. تحقق من الإنترنت ثم حاول مجددًا.'; if ((e && e.status) === 429 || m.includes('rate') || m.includes('seconds')) return 'تم إرسال طلبات كثيرة. انتظر قليلًا ثم حاول مجددًا.'; if (m.includes('expired') || m.includes('invalid')) return 'الرمز غير صحيح أو انتهت صلاحيته.'; if (m.includes('provider') || m.includes('not enabled') || m.includes('unsupported')) return 'تسجيل الدخول بالهاتف غير مفعّل بعد في هذه البيئة.'; return 'تعذّر إتمام العملية. حاول مرة أخرى.'; };
const toast = (t) => { const e = document.createElement('div'); e.className = 'w-toast'; e.setAttribute('role', 'status'); e.style.cssText = 'position:fixed;inset-inline:16px;bottom:88px;max-width:448px;margin:0 auto;z-index:9'; e.textContent = t; document.body.appendChild(e); setTimeout(() => e.remove(), 3000); };
function normPhone(v) { v = v.replace(/[\s\-()]/g, '').replace(/[٠-٩]/g, (d) => '٠١٢٣٤٥٦٧٨٩'.indexOf(d)); if (v.startsWith('+')) return /^\+\d{8,15}$/.test(v) ? v : null; v = v.replace(/^00/, ''); if (v.startsWith('967')) v = v.slice(3); v = v.replace(/^0/, ''); return /^7\d{8}$/.test(v) ? '+967' + v : null; }
let rt;
function rdmStart() { clearInterval(rt); let n = 0; rt = setInterval(async () => { const r = S.rdm; if (!r || r.done) { clearInterval(rt); return; } n++; const left = leftSec(r), e = $('#rtm'); if (e) e.textContent = mmss(left); if (!left) { clearInterval(rt); render(); return; }
  if (n % 8 === 0) { await load('cards', qCards); const k = (S.d.cards || []).find((c) => c.id === r.card_id); if (k && calc(k, S.d.rewards || []).have < r.before) { r.done = true; clearInterval(rt); await load('tx', qTx); render(); } } }, 1000); }
let tick;
function countdown() { clearInterval(tick); S.cd = 60; tick = setInterval(() => { S.cd = Math.max(0, S.cd - 1); const b = $('#rs'); if (b) { b.textContent = S.cd > 0 ? 'إعادة الإرسال بعد ' + S.cd + ' ث' : 'إعادة إرسال الرمز'; b.disabled = S.cd > 0; } if (!S.cd) clearInterval(tick); }, 1000); }
async function busy(fn) { if (S.busy) return; S.busy = true; render(); try { await fn(); } finally { S.busy = false; render(); } }
async function sendOtp(chan) {
  if (chan) S.chan = chan; S.err = ''; S.info = ''; let args;
  if (S.chan === 'email') { const em = S.email.trim().toLowerCase(); if (!/^\S+@\S+\.\S+$/.test(em)) { S.err = 'أدخل بريدًا إلكترونيًا صحيحًا.'; render(); return; } S.email = em; args = { email: em, options: { shouldCreateUser: true } }; }
  else { const p = normPhone(S.phone); if (!p) { S.err = 'أدخل رقم هاتف صحيحًا مكوّنًا من 9 أرقام يبدأ بـ 7.'; render(); return; } args = { phone: p }; }
  await busy(async () => { const { error } = await sb.auth.signInWithOtp(args); if (error) { S.err = AERR(error); return; } if (args.phone) S.phone = args.phone; S.tok = ''; S.step = 'otp'; countdown(); location.hash = '#/otp'; });
}
async function verify() {
  S.err = ''; const t = S.tok.replace(/\D/g, ''); if (!/^\d{6}$/.test(t)) { S.err = 'أدخل الرمز المكوّن من 6 أرقام.'; render(); return; }
  const args = S.chan === 'email' ? { email: S.email, token: t, type: 'email' } : { phone: S.phone, token: t, type: 'sms' };
  await busy(async () => { const { error } = await sb.auth.verifyOtp(args); if (error) { S.err = AERR(error); S.tok = ''; } });
}
async function act(a, v, el) {
  if (a === 'back') return history.length > 1 ? history.back() : (location.hash = '#/home');
  if (a === 'retry') { S.d = {}; render(); return loadAll(); }
  if (a === 'cat') { S.cat = v; return render(); }
  if (a === 'cf') { S.cf = v; return render(); }
  if (a === 'theme') { S.theme = v; ls.set('w-theme', v); const de = document.documentElement; if (de.classList) { de.classList.add('theme-anim'); setTimeout(() => de.classList.remove('theme-anim'), 450); } return render(); }
  if (a === 'claim') { const c = S.code.trim().toUpperCase(); if (!/^[A-Z0-9]{4}-?[A-Z0-9]{4}$/.test(c)) { S.claimRes = { ok: false, error: 'invalid_code' }; return render(); }
    return busy(async () => { const { data, error } = await sb.rpc('claim_earn_code', { p_code: c }); S.claimRes = error || !data ? { ok: false, error: 'x' } : data; if (S.claimRes.ok) { if (!S.claimRes.replay) S.just = { card: S.claimRes.card_id, n: +S.claimRes.added || 1, t: Date.now() }; S.code = ''; await Promise.all([load('cards', qCards), load('tx', qTx)]); } }); }
  if (a === 'redeem') { const [cid, rid] = v.split(':');
    return busy(async () => { const { data, error } = await sb.rpc('request_redeem', { p_card_id: cid, p_reward_id: rid }); if (error || !data || !data.ok) { toast(cerr(data && data.error)); return; } const k = (S.d.cards || []).find((c) => c.id === cid); S.rdm = { code: data.code, expires_at: data.expires_at, reward: data.reward, card_id: cid, reward_id: rid, before: k ? calc(k, S.d.rewards || []).have : 0, done: false }; location.hash = '#/redeem'; rdmStart(); }); }
  if (a === 'sendotp') return sendOtp('phone');
  if (a === 'resend') { if (S.cd > 0) return; S.err = ''; return sendOtp(); }
  if (a === 'verify') return verify();
  if (a === 'changephone') { S.step = 'phone'; S.err = ''; location.hash = '#/login'; return; }
  if (a === 'emailopen') { S.emailOpen = true; return render(); }
  if (a === 'email') return sendOtp('email');
  if (a === 'google') { const { error } = await sb.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: location.origin + location.pathname } }); if (error) { S.err = AERR(error); render(); } return; }
  if (a === 'fav') { const on = (S.d.favs || []).some((f) => f.merchant_id === v); const { error } = on ? await sb.from('favorites').delete().eq('merchant_id', v).eq('user_id', S.user.id) : await sb.from('favorites').insert({ merchant_id: v, user_id: S.user.id }); if (error) return toast('تعذّر تحديث المفضلة. تحقق من الاتصال.'); S.d.favs = on ? S.d.favs.filter((f) => f.merchant_id !== v) : [...(S.d.favs || []), { merchant_id: v }]; return render(); }
  if (a === 'join') return busy(async () => { const { data, error } = await sb.rpc('join_program', { p_program_id: v }); if (error) { toast(error.code === 'P0002' ? 'هذا البرنامج غير متاح حاليًا.' : 'تعذّر الانضمام. حاول مرة أخرى.'); return; } await load('cards', qCards); toast('انضممت إلى البرنامج.'); location.hash = '#/card/' + data; });
  if (a === 'savename') return busy(async () => { const { error } = await sb.from('profiles').update({ display_name: S.name.trim() || null }).eq('id', S.user.id); toast(error ? 'تعذّر حفظ الاسم.' : 'تم حفظ الاسم.'); });
  if (a === 'delreq') { S.sheet = { title: 'طلب حذف الحساب', body: 'سيُسجَّل طلبك ويُراجع وفق سياسة الخصوصية. لن تُحذف بياناتك فورًا.', ok: 'تأكيد الطلب', danger: true, run: 'delete' }; return render(); }
  if (a === 'sheet-no') { S.sheet = null; return render(); }
  if (a === 'sheet-yes') { const run = S.sheet && S.sheet.run; S.sheet = null; if (run === 'delete') return busy(async () => { const { error } = await sb.from('profiles').update({ deletion_requested_at: new Date().toISOString() }).eq('id', S.user.id); toast(error ? 'تعذّر تسجيل الطلب.' : 'تم تسجيل طلب حذف الحساب.'); }); return render(); }
  if (a === 'logout') { await sb.auth.signOut(); }
}
document.addEventListener('click', (e) => { const t = e.target.closest('[data-a]'); if (!t || t.disabled) return; const i = t.dataset.a.indexOf(':'); const a = i < 0 ? t.dataset.a : t.dataset.a.slice(0, i), v = i < 0 ? '' : t.dataset.a.slice(i + 1); act(a, v, t); });
document.addEventListener('input', (e) => { const id = e.target.id; if (id === 'phone') S.phone = e.target.value; else if (id === 'tok') S.tok = e.target.value; else if (id === 'email') S.email = e.target.value; else if (id === 'name') S.name = e.target.value; else if (id === 'code') S.code = e.target.value; else if (id === 'q') { S.q = e.target.value.trim(); const l = $('#list'); if (l) l.innerHTML = list(); } });
document.addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.target.id === 'code') act('claim', ''); if (e.key === 'Enter' && e.target.id === 'phone') sendOtp('phone'); if (e.key === 'Enter' && e.target.id === 'email') sendOtp('email'); if (e.key === 'Enter' && e.target.id === 'tok') verify(); });
window.addEventListener('hashchange', () => { S.err = ''; S.claimRes = null; S.anim = true; render(); window.scrollTo(0, 0); });
window.addEventListener('online', () => { S.online = true; render(); if (S.user) loadAll(); });
window.addEventListener('offline', () => { S.online = false; render(); });
// ---------- start ----------
async function init() {
  document.documentElement.setAttribute('data-theme', S.theme);
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js').catch(() => {});
  if (sb) {
    try { const r = await fetch(CFG.url + '/auth/v1/settings', { headers: { apikey: CFG.key } }); const j = await r.json(); const x = j.external || {}; S.authCfg = { phone: !!x.phone, email: !!x.email, google: !!x.google }; } catch { S.authCfg = { phone: true, email: false, google: false }; }
    const { data } = await sb.auth.getSession(); S.user = data.session ? data.session.user : null;
    sb.auth.onAuthStateChange((ev, s) => { const was = S.user; S.user = s ? s.user : null; if (ev === 'SIGNED_OUT') { Object.keys(localStorage).filter((k) => k.startsWith('wc:')).forEach((k) => ls.del(k)); S.d = {}; S.e = {}; S.phone = S.tok = ''; location.hash = '#/login'; render(); } else if (S.user && !was) { S.d = {}; location.hash = '#/home'; render(); loadAll(); } });
  }
  render(); if (S.user) loadAll();
  const sp = $('#splash');
  if (sp) {
    let seen = false; try { seen = sessionStorage.getItem('w-splash') === '1'; sessionStorage.setItem('w-splash', '1'); } catch {}
    if (seen) sp.remove(); else { const wait = typeof performance !== 'undefined' ? Math.max(0, 800 - performance.now()) : 0; setTimeout(() => { sp.classList.add('out'); setTimeout(() => sp.remove(), 350); }, wait); }
  }
}
init();
