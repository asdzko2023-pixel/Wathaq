// Builds showcase.html (one self-contained file) from tokens + components. Run: node packages/ui/build-showcase.mjs
import { readFileSync, writeFileSync } from 'node:fs';
const rd = (p) => readFileSync(new URL(p, import.meta.url), 'utf8');
const tokens = JSON.parse(rd('../design-tokens/tokens.json'));
const css = rd('../design-tokens/tokens.css') + rd('./components.css');
const I = {
  dia: '<path d="M12 2l7 11-7 9-7-9z"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>', clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  x: '<circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/>', info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
  home: '<path d="M4 11l8-7 8 7v8a1 1 0 0 1-1 1h-4v-6H9v6H5a1 1 0 0 1-1-1z"/>', compass: '<circle cx="12" cy="12" r="9"/><path d="M15.5 8.5l-2 5-5 2 2-5z"/>',
  cards: '<rect x="3" y="6" width="18" height="13" rx="3"/><path d="M3 10h18"/>', act: '<path d="M4 6h16M4 12h16M4 18h10"/>', user: '<circle cx="12" cy="8" r="4"/><path d="M4 20c1-4 4-6 8-6s7 2 8 6"/>',
  gift: '<rect x="4" y="10" width="16" height="10" rx="2"/><path d="M12 10v10M4 14h16"/>'
};
const ic = (n, c = '') => `<svg class="w-ico ${c}" viewBox="0 0 24 24" aria-hidden="true">${I[n]}</svg>`;
const dia = (on) => `<svg viewBox="0 0 24 32" aria-hidden="true"><path d="M12 2l9 14-9 14-9-14z"/></svg>`;
const stamps = (n, h, just) => `<ol class="w-stamps w-num" style="--cols:${n}" aria-label="${h} من ${n} أختام">${Array.from({ length: n }, (_, i) => `<li class="${i < h ? 'on' : 'off'}${i === just ? ' just' : ''}">${dia()}<span>${i + 1}</span></li>`).join('')}</ol>`;
const sw = (set) => Object.entries(tokens.semantic[set]).map(([k, v]) => `<div class="sw"><i style="background:${tokens.primitive[v]}"></i><b>${k}</b><code class="w-num">${tokens.primitive[v]}</code></div>`).join('');
const lcard = (m, l, name, prog, p, txt, n, h) => `<button class="w-lcard w-appear" style="--m:${m}"><div class="w-lcard__head"><span class="w-logo">${l}</span><div style="flex:1"><b>${name}</b><div style="font-size:var(--font-size-small);color:var(--color-text-muted)">${prog}</div></div><span class="w-num" style="font-weight:700">${txt}</span></div>${n ? `<div style="margin-block:12px">${stamps(n, h)}</div>` : `<div class="w-progress" style="margin-block:14px 4px" role="progressbar" aria-valuenow="${p}" aria-valuemin="0" aria-valuemax="100"><i style="--p:${p}%"></i></div>`}</button>`;
const body = `
<header class="top"><div><div class="brand">وِثاق</div><div class="muted">نظام التصميم · الإصدار 2</div></div><button class="w-btn w-btn--secondary" id="th" aria-pressed="false">الوضع الداكن</button></header>
<main>
<section><h2>الألوان (${'فاتح وداكن'})</h2><p class="muted">كل لون يمر بفحص تباين WCAG آلي عند كل بناء.</p><div class="sws">${sw('light')}</div><div class="sws dk">${sw('dark')}</div><div class="grad" role="img" aria-label="التدرج الذهبي المحدود"></div></section>
<section><h2>الخطوط</h2><div class="w-card"><div style="font-size:var(--font-size-display);font-weight:700;line-height:1.3">مزاياك تبدأ من مشترياتك</div><div style="font-size:var(--font-size-page);font-weight:600">عنوان الصفحة 28</div><div style="font-size:var(--font-size-section);font-weight:600">عنوان القسم 20</div><div style="font-size:var(--font-size-card-title);font-weight:600">عنوان البطاقة 18</div><p style="margin:0">النص الأساسي 16، لا يقل نص القراءة عن 14.</p><p class="muted" style="margin:0;font-size:var(--font-size-small)">النص الثانوي 14 &middot; <span class="w-num">WATHAQ 1,240</span></p></div></section>
<section><h2>الأزرار</h2><div class="row"><button class="w-btn w-btn--primary">إجراء أساسي</button><button class="w-btn w-btn--gold">ذهبي (محدود)</button><button class="w-btn w-btn--secondary">ثانوي</button><button class="w-btn w-btn--ghost">نصي</button><button class="w-btn w-btn--primary" disabled>معطّل</button><button class="w-btn w-btn--primary" aria-busy="true">جارٍ التحقق</button></div></section>
<section><h2>الحقول</h2><div class="w-card"><label class="w-field"><span>رقم الهاتف</span><input class="w-input w-num" dir="ltr" placeholder="+967"></label><label class="w-field"><span>رمز التحقق</span><input class="w-input" aria-invalid="true" aria-describedby="e1"><div class="w-error-text" id="e1">${ic('x', '')}الرمز غير صحيح. حاول مرة أخرى.</div></label></div></section>
<section><h2>الحالات (أيقونة ونص دائمًا)</h2><div class="row"><span class="w-badge w-badge--success">${ic('check')}مؤكدة</span><span class="w-badge w-badge--warning">${ic('clock')}قيد المعالجة</span><span class="w-badge w-badge--danger">${ic('x')}مرفوضة</span><span class="w-badge w-badge--info">${ic('info')}جديدة</span></div></section>
<section><h2>بطاقات الولاء</h2><div class="stack">${lcard('#1F5C4D', 'ق', 'مقهى النموذج', 'بطاقة أختام', 0, '5 / 8', 8, 5)}${lcard('#7A2E3B', 'ط', 'مطعم النموذج', 'برنامج نقاط', 60, '120 / 200 نقطة', 0, 0)}</div><button class="w-btn w-btn--secondary" id="pop">أعد تشغيل حركة الختم الجديد</button><div id="pp" class="w-card" style="margin-top:12px">${stamps(8, 6, 5)}</div><p class="muted">الحركة تُشغَّل فقط بعد تأكيد الخادم، وتُعطَّل عند تفضيل تقليل الحركة.</p></section>
<section><h2>التحميل والفراغ والخطأ</h2><div class="w-card"><div class="w-skel" style="height:20px;width:60%"></div><div class="w-skel" style="height:14px;width:90%;margin-block:10px"></div><div class="w-skel" style="height:8px;width:100%"></div></div><div class="w-card w-state">${ic('cards')}<h3>لم تنضم إلى أي برنامج ولاء بعد</h3><button class="w-btn w-btn--primary">اكتشف المتاجر</button></div><div class="w-card w-state">${ic('x')}<h3>تعذّر الاتصال بالخادم</h3><p>تحقق من الإنترنت ثم حاول مجددًا.</p><button class="w-btn w-btn--secondary">إعادة المحاولة</button></div><div class="w-toast" role="status">${ic('check')}تم تأكيد الختم من الخادم</div></section>
</main>
<nav class="w-nav" aria-label="التنقل الرئيسي"><a href="#" aria-current="page">${ic('home')}الرئيسية</a><a href="#">${ic('compass')}اكتشف</a><a href="#">${ic('cards')}بطاقاتي</a><a href="#">${ic('act')}نشاطي</a><a href="#">${ic('user')}حسابي</a></nav>`;
const page = `<!DOCTYPE html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"><title>وِثاق | نظام التصميم</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;500;600;700&family=Inter:wght@500;600&display=swap">
<style>${css}
body{margin:0;background:var(--color-bg)}.top{display:flex;justify-content:space-between;align-items:center;padding:var(--space-4);padding-top:calc(var(--space-4) + env(safe-area-inset-top,0px));background:var(--color-obsidian,#0B0B0D);color:#fff}
.brand{font-size:var(--font-size-page);font-weight:700;color:#F2D98D}.top .muted{color:#A9A9B2}.muted{color:var(--color-text-muted);font-size:var(--font-size-small)}
main{max-width:720px;margin:0 auto;padding:var(--space-4) var(--space-4) 96px}section{margin-block:var(--space-6)}h2{font-size:var(--font-size-section);margin:0 0 var(--space-3)}
.row{display:flex;flex-wrap:wrap;gap:var(--space-2)}.stack{display:grid;gap:var(--space-3);margin-block-end:var(--space-3)}
.sws{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:var(--space-2);margin-block-end:var(--space-3)}.sw{background:var(--color-surface);border:1px solid var(--color-border);border-radius:var(--radius-md);padding:var(--space-2);font-size:var(--font-size-caption)}
.sw i{display:block;height:32px;border-radius:6px;margin-block-end:4px;border:1px solid var(--color-border)}.sw b{display:block;font-size:var(--font-size-small)}.sw code{color:var(--color-text-muted)}.sws.dk .sw{background:#151519;color:#fff;border-color:#303036}.sws.dk code{color:#A9A9B2}
.grad{height:40px;border-radius:var(--radius-md);background:var(--gradient-gold)}
.w-nav{position:fixed;inset-inline:0;bottom:0}.w-card+.w-card{margin-block-start:var(--space-3)}
</style></head><body><div class="w-app" id="root">${body}</div>
<script>
var r=document.documentElement,b=document.getElementById('th');
b.addEventListener('click',function(){var d=r.getAttribute('data-theme')==='dark';r.setAttribute('data-theme',d?'light':'dark');b.setAttribute('aria-pressed',String(!d));b.textContent=d?'الوضع الداكن':'الوضع الفاتح'});
document.getElementById('pop').addEventListener('click',function(){var e=document.querySelector('#pp .just');e.classList.remove('just');void e.offsetWidth;e.classList.add('just')});
</script></body></html>`;
writeFileSync(new URL('./showcase.html', import.meta.url), page);
console.log('showcase.html', page.length, 'bytes');
