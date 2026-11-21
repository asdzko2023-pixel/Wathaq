import { Capacitor } from '@capacitor/core';
import { App } from '@capacitor/app';
import { Browser } from '@capacitor/browser';

const createClient = window.supabase?.createClient;
const cfg = window.WATHAQ_CONFIG || {};
const isNative = Capacitor.isNativePlatform();
const NATIVE_AUTH_CALLBACK = 'com.wathaq.app://auth/callback';
const sb = createClient && cfg.url && cfg.key ? createClient(cfg.url,cfg.key,{auth:{persistSession:true,autoRefreshToken:true,flowType:'pkce',detectSessionInUrl:!isNative}}) : null;
const $ = (s,r=document)=>r.querySelector(s);
const esc = s => String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const state={view:'customer',user:null,merchant:null,accounts:[],programs:[],rewards:[],favorites:[],ledger:[],merchants:[],merchantLedger:[],canManageMerchant:false};
const app=$('#app'),dialog=$('#authDialog'),toast=$('#toast');let stopScanner=null;
if(!sb){app.innerHTML='<section class="panel empty"><b>واجهة وِثاق محفوظة على جهازك</b>تعذر تحميل مكتبة الاتصال. تحقق من الإنترنت ثم أعد فتح التطبيق.</section>';throw new Error('Supabase client library unavailable')}
const money=n=>new Intl.NumberFormat('ar-YE',{maximumFractionDigits:0}).format(Number(n||0));
function fileExt(file){return ({'image/jpeg':'jpg','image/png':'png','image/webp':'webp','image/avif':'avif'})[file?.type]||null}
function publicImage(bucket,path){return path?sb.storage.from(bucket).getPublicUrl(path).data.publicUrl:''}
function displayCode(code,label,ttl){app.insertAdjacentHTML('afterbegin','<div class="code-box" style="margin-bottom:18px"><span class="tag gold">'+label+'</span><canvas id="tokenQr" width="170" height="170"></canvas><strong>'+esc(code)+'</strong><small>صالح لمدة '+ttl+' ثانية. اعرض الرمز على موظف المتجر.</small></div>');if(window.QRCode?.toCanvas)window.QRCode.toCanvas($('#tokenQr'),code,{width:170,margin:1,errorCorrectionLevel:'H'},err=>{if(err)console.error(err)});}
async function startScanner(target){if(!navigator.mediaDevices?.getUserMedia||!('BarcodeDetector' in window)){notify('المتصفح لا يدعم المسح بالكاميرا. أدخل الرمز يدوياً.');return}try{const detector=new BarcodeDetector({formats:['qr_code']}),video=$('#scanVideo'),modal=$('#scanDialog'),stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:'environment'}},audio:false});video.srcObject=stream;await video.play();let active=true;const stop=()=>{active=false;stream.getTracks().forEach(t=>t.stop());video.srcObject=null;if(modal.open)modal.close();stopScanner=null};stopScanner=stop;modal.showModal();const scan=async()=>{if(!active)return;try{const found=await detector.detect(video);if(found.length&&found[0].rawValue){const input=document.getElementById(target);if(input)input.value=found[0].rawValue.trim().toUpperCase();stop();notify('تمت قراءة الرمز بنجاح');return}}catch(err){console.error(err)}if(active)requestAnimationFrame(scan)};requestAnimationFrame(scan)}catch(err){notify('تعذر تشغيل الكاميرا: '+(err.message||'تحقق من الإذن'))}}
function notify(s){toast.textContent=s;toast.classList.add('show');setTimeout(()=>toast.classList.remove('show'),2600)}
function icon(type){const p={star:'<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3l-5.6 2.9 1.1-6.2L3 9.6l6.2-.9z"/>',store:'<path d="M3 10h18l-2-6H5zM5 10v10h14V10M9 20v-6h6v6"/>',gift:'<path d="M3 10h18v11H3zM2 6h20v4H2zM12 6v15M12 6H8a2 2 0 1 1 2-2c0 1.1 2 2 2 2zm0 0h4a2 2 0 1 0-2-2c0 1.1-2 2-2 2z"/>',thread:'<path d="M4 6c4-4 12-4 16 0M4 18c4 4 12 4 16 0M4 6l16 12M4 18 20 6"/>'};return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'+(p[type]||p.thread)+'</svg>'}
function top(t,s){return '<div class="section-head"><div><h2>'+t+'</h2><p>'+s+'</p></div></div>'}
function hero(e,t,d,a=''){return '<section class="hero"><div class="hero-content"><div class="eyebrow">'+e+'</div><h1>'+t+'</h1><p>'+d+'</p><div class="hero-actions">'+a+'</div></div><div class="hero-art">'+icon('thread')+'</div></section>'}
function render(){
 const customer=state.view==='customer';
 document.body.classList.toggle('customer-mode',customer);
 const bar=$('.topbar');if(bar)bar.hidden=customer;
 $('#authButton').hidden=!!state.user;$('#profileButton').hidden=!state.user;
 if(state.user)$('#profileButton').textContent=(state.user.phone||state.user.email||'و').slice(-1).toUpperCase();
 document.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',b.dataset.view===state.view));
 if(customer)renderCustomer();else if(state.view==='merchant')renderMerchant();else{state.view='customer';renderCustomer()}
}
async function customerData(){
 const [a,p,r,t,f]=await Promise.all([
  sb.from('loyalty_accounts').select('id,points_balance,stamps_balance,joined_at,merchant_id,program_id,merchants(name,category,logo_path),loyalty_programs!loyalty_accounts_merchant_id_program_id_fkey(name,kind,stamp_goal)').eq('customer_id',state.user.id).order('last_activity_at',{ascending:false}),
  sb.from('loyalty_programs').select('id,name,kind,description,stamp_goal,merchant_id,merchants(name,category,logo_path)').eq('state','active').limit(30),
  sb.from('rewards').select('id,title,description,points_cost,stamps_cost,program_id,merchant_id,image_path,loyalty_programs!rewards_merchant_id_program_id_fkey(name,kind)').eq('is_active',true).limit(50),
  sb.from('loyalty_ledger').select('id,kind,points_delta,stamps_delta,created_at,reference,merchants(name)').eq('customer_id',state.user.id).order('created_at',{ascending:false}).limit(12),
  sb.from('favorites').select('merchant_id').eq('customer_id',state.user.id)
 ]);
 if(a.error)throw a.error;if(p.error)throw p.error;if(r.error)throw r.error;if(t.error)throw t.error;if(f.error)throw f.error;
 state.accounts=a.data||[];state.programs=p.data||[];state.rewards=r.data||[];state.ledger=t.data||[];state.favorites=f.data||[];
}
function customerIcon(name){
 const p={
 bell:'<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"/><path d="M10 21h4"/>',
 search:'<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
 store:'<path d="M3 10h18l-2-6H5z"/><path d="M5 10v10h14V10M9 20v-6h6v6"/>',
 tag:'<path d="M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8Z"/><circle cx="7.5" cy="7.5" r="1"/>',
 gift:'<path d="M3 10h18v11H3zM2 6h20v4H2zM12 6v15"/><path d="M12 6H8a2 2 0 1 1 2-2c0 1.1 2 2 2 2Zm0 0h4a2 2 0 1 0-2-2c0 1.1-2 2-2 2Z"/>',
 scan:'<path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3"/><path d="M7 12h10M7 15h6M7 9h2m6 0h2"/>',
 home:'<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z"/>',
 user:'<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
 clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
 arrow:'<path d="M5 12h14m-6-6 6 6-6 6"/>',
 star:'<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3l-5.6 2.9 1.1-6.2L3 9.6l6.2-.9z"/>',
 crown:'<path d="m3 8 4 4 5-8 5 8 4-4-2 11H5Z"/><path d="M5 22h14"/>',
 check:'<path d="m5 12 4 4L19 6"/>'
 };
 return '<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'+(p[name]||p.star)+'</svg>';
}
function renderCustomer(){
 const signed=!!state.user;
 const totalPoints=state.accounts.reduce((n,a)=>n+Number(a.points_balance||0),0);
 const totalStamps=state.accounts.reduce((n,a)=>n+Number(a.stamps_balance||0),0);
 const name=state.user?.user_metadata?.full_name||state.user?.user_metadata?.name||state.user?.email?.split('@')[0]||'ضيف وِثاق';
 const hour=new Date().getHours(),greeting=hour<12?'صباح الخير':hour<18?'مساء الخير':'مساء النور';
 const avatar=state.user?.user_metadata?.avatar_url||state.user?.user_metadata?.picture||'';
 const initials=esc((name.trim().split(/\s+/).slice(-1)[0]||'و').slice(0,1));
 const progressData=state.accounts.map(a=>{
  const kind=a.loyalty_programs?.kind,have=Number(kind==='stamps'?a.stamps_balance:a.points_balance)||0;
  const costs=state.rewards.filter(r=>r.program_id===a.program_id).map(r=>Number(kind==='stamps'?r.stamps_cost:r.points_cost)||0).filter(x=>x>0).sort((x,y)=>x-y);
  const target=kind==='stamps'?Number(a.loyalty_programs?.stamp_goal)||0:(costs[0]||0);
  return {have,target,pct:target?Math.min(100,Math.round(have/target*100)):0,unit:kind==='stamps'?'ختم':'نقطة'};
 }).filter(x=>x.target).sort((a,b)=>b.pct-a.pct)[0];
 const progress=progressData?.pct||0;
 const progressCopy=progressData?'باقي '+money(Math.max(0,progressData.target-progressData.have))+' '+progressData.unit+' للمكافأة القادمة':'انضم إلى برنامج ولاء وابدأ جمع المكافآت';
 const accountCards=state.accounts.length?state.accounts.map(a=>{
  const unit=a.loyalty_programs?.kind==='stamps'?'ختم':'نقطة',amount=unit==='ختم'?a.stamps_balance:a.points_balance;
  return '<article class="customer-program-card"><div class="customer-program-mark">'+customerIcon('store')+'</div><div class="customer-program-copy"><b>'+esc(a.loyalty_programs?.name||'برنامج الولاء')+'</b><small>'+esc(a.merchants?.name||'متجر مشارك')+'</small><strong>'+money(amount)+' '+unit+'</strong></div><button class="customer-mini-action" data-earn="'+a.program_id+'" aria-label="إظهار رمز الاكتساب">'+customerIcon('scan')+'</button></article>';
 }).join(''):'<div class="customer-empty"><b>رصيدك الأول بانتظارك</b><span>اكتشف المتاجر المشاركة وانضم إلى برامج الولاء لتبدأ جمع النقاط والأختام.</span><a href="#wathaq-stores">اكتشف المتاجر</a></div>';
 const programs=state.programs.length?state.programs.map(p=>'<article class="customer-program-card" data-program-card data-search="'+esc((p.name+' '+(p.merchants?.name||'')+' '+(p.description||'')).toLowerCase())+'"><div class="customer-program-mark">'+customerIcon('store')+'</div><div class="customer-program-copy"><b>'+esc(p.name)+'</b><small>'+esc(p.merchants?.name||'متجر مشارك')+' · '+(p.kind==='points'?'برنامج نقاط':'برنامج أختام')+'</small><span>'+esc(p.description||'انضم واكتشف مزايا هذا البرنامج.')+'</span></div><button class="customer-mini-action" data-join="'+p.id+'" aria-label="انضمام">'+customerIcon('arrow')+'</button></article>').join(''):'<div class="customer-empty">لا توجد برامج نشطة حالياً.</div>';
 const rewards=state.rewards.length?state.rewards.map(r=>'<article class="customer-reward-card">'+(r.image_path?'<img src="'+esc(publicImage('reward-media',r.image_path))+'" alt="'+esc(r.title)+'">':'<div class="customer-reward-art">'+customerIcon('gift')+'</div>')+'<div><b>'+esc(r.title)+'</b><small>'+esc(r.loyalty_programs?.name||'مكافأة من المتجر')+'</small><strong>'+money(r.points_cost||r.stamps_cost)+' '+(r.loyalty_programs?.kind==='points'?'نقطة':'ختم')+'</strong><button class="btn btn-gold" data-redeem="'+r.id+'" data-account="'+(state.accounts.find(a=>a.program_id===r.program_id)?.id||'')+'">طلب الاستبدال</button></div></article>').join(''):'<div class="customer-empty">ستظهر هنا المكافآت المنشورة من المتاجر المشاركة.</div>';
 const activities=state.ledger.length?state.ledger.slice(0,3).map(x=>{
  const positive=Number(x.points_delta||0)>0||Number(x.stamps_delta||0)>0;
  const amount=Number(x.points_delta||0)>0?'+'+money(x.points_delta)+' نقطة':Number(x.stamps_delta||0)>0?'+'+money(x.stamps_delta)+' ختم':'تم استبدال مكافأة';
  const when=new Date(x.created_at).toLocaleString('ar-YE',{dateStyle:'medium',timeStyle:'short'});
  return '<article class="customer-activity-row"><span class="customer-activity-icon '+(positive?'earned':'redeemed')+'">'+customerIcon(positive?'gift':'check')+'</span><div class="customer-activity-copy"><b>'+esc(amount)+'</b><small>'+esc(x.merchants?.name||'متجر مشارك')+'</small></div><time>'+esc(when)+'</time></article>';
 }).join(''):'<div class="customer-empty">ستظهر أحدث عمليات اكتساب النقاط واستبدال المكافآت هنا بعد أول عملية.</div>';
 const firstAccount=state.accounts[0];
 const scanAction=firstAccount?'<button class="customer-scan-fab" data-earn="'+firstAccount.program_id+'" aria-label="إظهار رمز وِثاق">'+customerIcon('scan')+'</button>':'<a class="customer-scan-fab" href="#wathaq-stores" aria-label="اكتشف برامج الولاء">'+customerIcon('scan')+'</a>';
 const profileAction=signed?'<button class="customer-avatar" type="button" data-profile title="حسابي">'+(avatar?'<img src="'+esc(avatar)+'" alt="">':initials)+'</button>':'<button class="customer-avatar guest" data-login aria-label="تسجيل الدخول">'+customerIcon('user')+'</button>';
 app.innerHTML='<div class="wathaq-home customer-app">'+
  '<header class="customer-header"><div class="customer-header-row"><div class="customer-header-actions"><button class="customer-round-action" data-notify aria-label="الإشعارات">'+customerIcon('bell')+'</button><a class="customer-round-action" href="#wathaq-stores" aria-label="البحث">'+customerIcon('search')+'</a></div><div class="customer-brand"><img src="./wathaq-logo.svg" alt="وثاق WATHAQ"></div><div class="customer-welcome"><div><small>'+greeting+'</small><b>'+esc(name)+'</b></div>'+profileAction+'</div></div></header>'+
  '<section class="customer-balance-card"><div class="customer-level-side"><div class="customer-crown">'+customerIcon('crown')+'</div><small>المستوى الحالي</small><strong>عضو وِثاق <span>✦</span></strong><a href="#wathaq-rewards">مزايا المستوى <span>‹</span></a></div><div class="customer-points-side"><small>رصيد نقاطك</small><div class="customer-points-value">'+money(totalPoints)+'<span>'+customerIcon('star')+'</span></div><div class="customer-progress"><i style="width:'+progress+'%"></i></div><p>'+esc(progressCopy)+'</p><small class="customer-stamps">إجمالي الأختام: '+money(totalStamps)+'</small></div></section>'+
  '<section class="customer-quick-grid" aria-label="اختصارات"><a class="customer-quick-tile" href="#wathaq-stores"><span>'+customerIcon('store')+'</span><b>متاجري</b></a><a class="customer-quick-tile" href="#wathaq-offers"><span>'+customerIcon('tag')+'</span><b>عروضي</b></a><a class="customer-quick-tile" href="#wathaq-rewards"><span>'+customerIcon('gift')+'</span><b>مكافآتي</b></a><a class="customer-quick-tile" href="#wathaq-stores"><span>'+customerIcon('scan')+'</span><b>مسح رمز المتجر</b></a></section>'+
  '<section class="customer-promo"><div class="customer-promo-art"><span>✦</span><b>W</b></div><div class="customer-promo-copy"><small>أقرب لك دائماً</small><h2>مكافآت وعروض حصرية</h2><p>اكتشف مزايا متاجرك المفضلة</p><a href="#wathaq-offers">اكتشف الآن '+customerIcon('arrow')+'</a></div></section>'+
  '<section class="customer-activity-section"><div class="customer-section-head"><h2>'+customerIcon('clock')+' أحدث الأنشطة</h2><a href="#wathaq-activity">عرض الكل ‹</a></div><div class="customer-activity-list">'+activities+'</div></section>'+
  '<a class="customer-coming" href="#wathaq-stores"><div class="customer-rocket">🚀</div><div><small>قريباً</small><b>مزايا جديدة في انتظارك</b><span>المزيد من الخدمات والمكافآت المميزة</span></div><span class="customer-coming-arrow">'+customerIcon('arrow')+'</span></a>'+
  '<section class="customer-extra-section" id="wathaq-stores"><div class="customer-section-head"><h2>'+customerIcon('store')+' برامج الولاء</h2><a href="#wathaq-stores">عرض الكل</a></div><div class="field"><input id="programSearch" type="search" placeholder="ابحث عن متجر أو برنامج..." aria-label="البحث عن متجر أو برنامج"></div><div class="customer-program-list">'+programs+'</div></section>'+
  '<section class="customer-extra-section" id="wathaq-offers"><div class="customer-section-head"><h2>'+customerIcon('gift')+' المكافآت المتاحة</h2><a href="#wathaq-rewards">بطاقاتي</a></div><div class="customer-reward-grid">'+rewards+'</div></section>'+
  '<section class="customer-extra-section" id="wathaq-rewards"><div class="customer-section-head"><h2>'+customerIcon('star')+' بطاقات ولائي</h2><a href="#wathaq-activity">النشاط</a></div><div class="customer-program-list">'+accountCards+'</div></section>'+
  '<section class="customer-extra-section" id="wathaq-activity"><div class="customer-section-head"><h2>'+customerIcon('clock')+' سجل النشاط</h2></div><div class="customer-activity-list">'+activities+'</div></section>'+
  '<section class="customer-account-section" id="wathaq-account"><div class="customer-section-head"><h2>'+customerIcon('user')+' حسابي</h2></div><div class="customer-account-card"><div class="customer-avatar account-avatar">'+(avatar?'<img src="'+esc(avatar)+'" alt="">':initials)+'</div><div><b>'+esc(name)+'</b><small>'+esc(state.user?.email||'حساب وِثاق')+'</small></div></div><button class="customer-merchant-entry" data-view="merchant">هل تدير متجراً؟ <b>الدخول إلى بوابة التاجر</b>'+customerIcon('arrow')+'</button></section><nav class="customer-bottom-nav" aria-label="التنقل الرئيسي"><a href="#wathaq-account">'+customerIcon('user')+'<small>حسابي</small></a><a href="#wathaq-offers">'+customerIcon('tag')+'<small>العروض</small></a>'+scanAction+'<a href="#wathaq-stores">'+customerIcon('store')+'<small>المتاجر</small></a><a class="active" href="#">'+customerIcon('home')+'<small>الرئيسية</small></a></nav>'+
 '</div>';
}
function renderMerchant(){
 if(!state.user){app.innerHTML=hero('بوابة الشركاء','حوّل العملاء إلى مجتمع وفيّ.','منصة متكاملة لإدارة برامج الولاء، ومتابعة أداء متجرك، وبناء علاقة طويلة الأمد مع عملائك.','<button class="btn btn-gold" data-login>دخول لوحة التاجر</button>');return}
 if(!state.merchant){app.innerHTML=hero('مساحة التاجر','ابدأ ببناء برنامج ولاء يحمل هوية متجرك.','أنشئ ملف متجرك، ثم أطلق برنامج النقاط أو الأختام خلال دقائق.','<span class="tag gold">حساب جديد</span>')+top('تسجيل متجرك','ستتم مراجعة المتجر قبل تفعيله للعملاء.')+'<div class="panel"><form id="merchantCreate"><div class="form-grid"><div class="field"><label>اسم المتجر</label><input name="name" required minlength="2" placeholder="مثال: مقهى الوِثاق"></div><div class="field"><label>التصنيف</label><select name="category"><option>مطاعم ومقاهي</option><option>ملابس</option><option>عطور وتجميل</option><option>تجزئة</option><option>أخرى</option></select></div><div class="field"><label>المدينة</label><input name="city" placeholder="عدن"></div><div class="field"><label>وصف مختصر</label><input name="description" placeholder="ما الذي يميز متجرك؟"></div><div class="field"><label>شعار المتجر (اختياري)</label><input name="logo" type="file" accept="image/png,image/jpeg,image/webp,image/avif"></div></div><button class="btn btn-gold">إنشاء ملف المتجر</button></form></div>';return}
 const m=state.merchant;if(!state.canManageMerchant){app.innerHTML='<div class="empty"><b>هذا الحساب لا يملك صلاحية إدارة المتجر</b>تواصل مع مالك المتجر لمراجعة صلاحيات حسابك.</div>';return}const programs=m.loyalty_programs||[],customers=(m.loyalty_accounts||[]).length,points=(m.loyalty_accounts||[]).reduce((s,a)=>s+a.points_balance,0);
 app.innerHTML='<div class="eyebrow">لوحة التاجر · '+esc(m.slug)+'</div>'+hero('مركز إدارة الولاء',esc(m.name),'تحكم في برامجك ومكافآتك، وراقب تفاعل العملاء من لوحة واحدة.','<span class="tag '+(m.status==='active'?'':'gold')+'">'+({pending:'بانتظار المراجعة',active:'متجر نشط',suspended:'موقوف',rejected:'مرفوض'}[m.status]||m.status)+'</span>')+top('نظرة عامة','أداء متجرك في لمحة واحدة.')+'<div class="stat-grid"><div class="stat"><span>برامج الولاء</span><strong>'+programs.length+'</strong></div><div class="stat"><span>حسابات العملاء</span><strong>'+customers+'</strong></div><div class="stat"><span>النقاط المتداولة</span><strong>'+money(points)+'</strong></div><div class="stat"><span>حالة المتجر</span><strong style="font:600 14px IBM Plex Sans Arabic">'+(m.status==='active'?'نشط':'قيد المراجعة')+'</strong></div></div>'+merchantActivityMarkup()+top('برامج الولاء','أطلق برنامجاً أو طوّر قواعد برنامج قائم.')+'<div class="grid">'+(programs.length?programs.map(p=>'<article class="panel"><div class="panel-head"><span class="tag '+(p.state==='active'?'':'gray')+'">'+({active:'نشط',draft:'مسودة',paused:'متوقف',archived:'مؤرشف'}[p.state]||p.state)+'</span><span class="muted">v'+p.version+'</span></div><h3>'+esc(p.name)+'</h3><p class="muted">'+(p.kind==='points'?'برنامج نقاط':'برنامج أختام')+'</p><button class="btn btn-soft" data-program-state="'+(p.state==='active'?'paused':'active')+'" data-program-id="'+p.id+'">'+(p.state==='active'?'إيقاف مؤقت':'نشر البرنامج')+'</button></article>').join(''):'<div class="empty">لم تنشئ برنامجاً بعد.</div>')+'</div>'+top('إضافة مكافأة','اربط المكافأة ببرنامج ولاء محدد.')+'<div class="panel"><form id="rewardCreate"><div class="form-grid"><div class="field"><label>البرنامج</label><select name="program_id" required>'+programs.map(p=>'<option value="'+p.id+'">'+esc(p.name)+'</option>').join('')+'</select></div><div class="field"><label>اسم المكافأة</label><input name="title" required placeholder="مثال: قهوة مجانية"></div><div class="field"><label>تكلفة النقاط أو الأختام</label><input name="cost" type="number" min="1" step="1" required></div><div class="field"><label>وصف المكافأة</label><input name="description" placeholder="تفاصيل وشروط الاستبدال"></div><div class="field"><label>المخزون (اتركه فارغاً للمخزون المفتوح)</label><input name="stock" type="number" min="0" step="1" placeholder="غير محدود"></div><div class="field"><label>صورة المكافأة (اختياري)</label><input name="image" type="file" accept="image/png,image/jpeg,image/webp,image/avif"></div></div><button class="btn btn-gold">حفظ المكافأة</button></form></div>'+top('إنشاء برنامج جديد','ابدأ بإعداد نوع الولاء وقواعده الأساسية.')+'<div class="panel"><form id="programCreate"><div class="form-grid"><div class="field"><label>اسم البرنامج</label><input name="name" required placeholder="مثال: نقاط النخبة"></div><div class="field"><label>نوع البرنامج</label><select name="kind"><option value="points">نقاط</option><option value="stamps">أختام</option></select></div><div class="field"><label>نقاط لكل وحدة من العملة</label><input name="rate" type="number" min=".01" step=".01" value="1"></div><div class="field"><label>عدد الأختام للمكافأة</label><input name="goal" type="number" min="2" max="100" value="10"></div><div class="field"><label>الحد الأدنى للشراء لكل ختم (ريال)</label><input name="minimum_purchase" type="number" min="0" step="1" value="0"></div><div class="field"><label>وصف البرنامج</label><input name="description" placeholder="اكتب كيف يكافئ البرنامج عملاءك"></div></div><button class="btn btn-gold">إنشاء البرنامج</button></form></div>';
}
async function refresh(){
 if(!sb){app.innerHTML='<div class="empty">إعداد الاتصال غير مكتمل.</div>';return}
 const {data:{session}}=await sb.auth.getSession();state.user=session?.user||null;
 if(!state.user){render();return}
 try{if(state.view==='customer')await customerData();if(state.view==='merchant')await merchantData();render()}catch(e){console.error(e);app.innerHTML='<div class="empty"><b>تعذر تحميل البيانات</b>'+esc(e.message||'خطأ غير معروف')+'<br><button class="btn btn-soft" data-refresh>إعادة المحاولة</button></div>'}
}
async function action(fn){const x=await fn();if(x?.error)throw x.error;return x?.data??x}
document.addEventListener('input',e=>{if(e.target.id==='programSearch'){const q=e.target.value.trim().toLowerCase();document.querySelectorAll('[data-program-card]').forEach(card=>{card.hidden=!card.dataset.search.includes(q)})}});
document.addEventListener('click',async e=>{
 const v=e.target.closest('[data-view]');if(v){state.view=v.dataset.view;refresh();return}
 const statusBtn=e.target.closest('[data-merchant-status]');if(statusBtn){try{const {error}=await sb.from('merchants').update({status:statusBtn.dataset.merchantStatus}).eq('id',statusBtn.dataset.merchantId);if(error)throw error;notify(statusBtn.dataset.merchantStatus==='active'?'تم اعتماد المتجر':'تم رفض الطلب');await refresh()}catch(err){notify(err.message)}return}
 if(e.target.closest('[data-login]')||e.target.id==='authButton'){dialog.showModal();return}
  if(e.target.closest('[data-notify]')){notify('الإشعارات ستكون متاحة قريباً');return}
  if(e.target.closest('[data-profile]')){notify('إعدادات الحساب قيد التجهيز');return}
 if(e.target.closest('[data-close]')){dialog.close();return}
 if(e.target.closest('[data-scan-close]')){if(stopScanner)stopScanner();return}
 const scanBtn=e.target.closest('[data-scan-target]');if(scanBtn){startScanner(scanBtn.dataset.scanTarget);return}
 const favoriteBtn=e.target.closest('[data-favorite-merchant]');if(favoriteBtn){try{const merchantId=favoriteBtn.dataset.favoriteMerchant;if(favoriteBtn.dataset.favorite==='true'){const {error}=await sb.from('favorites').delete().eq('customer_id',state.user.id).eq('merchant_id',merchantId);if(error)throw error;notify('أزلنا المتجر من المفضلة')}else{const {error}=await sb.from('favorites').insert({customer_id:state.user.id,merchant_id:merchantId});if(error)throw error;notify('أضفنا المتجر إلى المفضلة')}await refresh()}catch(err){notify(err.message)}return}
 const programStateBtn=e.target.closest('[data-program-state]');if(programStateBtn){try{const {error}=await sb.from('loyalty_programs').update({state:programStateBtn.dataset.programState}).eq('id',programStateBtn.dataset.programId);if(error)throw error;notify(programStateBtn.dataset.programState==='active'?'تم نشر البرنامج':'تم إيقاف البرنامج مؤقتاً');await refresh()}catch(err){notify(err.message)}return}
 const memberToggle=e.target.closest('[data-member-toggle]');if(memberToggle){try{const {error}=await sb.rpc('set_merchant_member',{p_merchant_id:state.merchant.id,p_user_id:memberToggle.dataset.memberToggle,p_active:memberToggle.dataset.active!=='true'});if(error)throw error;notify('تم تحديث صلاحية الموظف');await refresh()}catch(err){notify(err.message)}return}
 if(e.target.closest('[data-refresh]')){await refresh();return}
 const j=e.target.closest('[data-join]');if(j){try{await action(()=>sb.rpc('join_loyalty_program',{p_program_id:j.dataset.join}));notify('تم الانضمام إلى البرنامج بنجاح');await refresh()}catch(err){notify(err.message)}return}
 const redeem=e.target.closest('[data-redeem]');if(redeem){try{if(!redeem.dataset.account)throw new Error('انضم إلى البرنامج أولاً');const r=await action(()=>sb.rpc('create_redeem_code',{p_account_id:redeem.dataset.account,p_reward_id:redeem.dataset.redeem}));if(!r.ok)throw new Error(r.error);displayCode(r.code,'رمز استبدال مؤقت',r.expires_in);notify('تم إصدار رمز الاستبدال')}catch(err){notify(err.message)}return}
 const earn=e.target.closest('[data-earn]');if(earn){try{const r=await action(()=>sb.rpc('create_customer_checkin_code',{p_program_id:earn.dataset.earn}));if(!r.ok)throw new Error(r.error);displayCode(r.code,'رمز اكتساب مؤقت',r.expires_in);notify('تم إصدار رمز مؤقت')}catch(err){notify(err.message)}}
});
document.addEventListener('submit',async e=>{
 const form=e.target;if(!form.matches('#merchantCreate,#programCreate,#rewardCreate'))return;e.preventDefault();
 try{
  if(!state.user)throw new Error('سجّل الدخول أولاً');
  const f=new FormData(form);
  if(form.id==='merchantCreate'){
   const name=String(f.get('name')).trim(),slug='merchant-'+crypto.randomUUID().slice(0,8);
   const created=await action(()=>sb.from('merchants').insert({owner_user_id:state.user.id,name,slug,category:f.get('category'),city:f.get('city'),description:f.get('description')}).select('id').single());
   const logo=f.get('logo');if(logo?.size){const ext=fileExt(logo);if(!ext)throw new Error('صيغة صورة الشعار غير مدعومة');const path=created.id+'/logo.'+ext;const up=await sb.storage.from('merchant-branding').upload(path,logo,{upsert:true});if(up.error)throw up.error;const upd=await sb.from('merchants').update({logo_path:path}).eq('id',created.id);if(upd.error)throw upd.error;}
   notify('تم إنشاء ملف المتجر وهو بانتظار المراجعة');await refresh();return;
  }
  if(form.id==='rewardCreate'){
   const pid=f.get('program_id'),program=state.merchant.loyalty_programs.find(p=>p.id===pid),cost=Number(f.get('cost'));
   const created=await action(()=>sb.from('rewards').insert({merchant_id:state.merchant.id,program_id:pid,title:f.get('title'),description:f.get('description'),points_cost:program?.kind==='points'?cost:null,stamps_cost:program?.kind==='stamps'?cost:null,stock_quantity:f.get('stock')===''?null:Number(f.get('stock')),is_active:true}).select('id').single());
   const image=f.get('image');if(image?.size){const ext=fileExt(image);if(!ext)throw new Error('صيغة صورة المكافأة غير مدعومة');const path=state.merchant.id+'/rewards/'+created.id+'.'+ext;const up=await sb.storage.from('reward-media').upload(path,image,{upsert:true});if(up.error)throw up.error;const upd=await sb.from('rewards').update({image_path:path}).eq('id',created.id);if(upd.error)throw upd.error;}
   notify('تم حفظ المكافأة');await refresh();return;
  }
  if(form.id==='programCreate'){
   await action(()=>sb.from('loyalty_programs').insert({merchant_id:state.merchant.id,name:f.get('name'),kind:f.get('kind'),description:f.get('description'),points_per_currency:Number(f.get('rate')),stamp_goal:Number(f.get('goal')),rules:{minimum_purchase:Number(f.get('minimum_purchase')||0)},state:'draft'}));
   notify('تم إنشاء البرنامج كمسودة');await refresh();return;
  }
  }catch(err){notify(err.message||'حدث خطأ غير متوقع')}
});
$('#authButton').addEventListener('click',()=>dialog.showModal());
$('#googleSignIn').addEventListener('click',async()=>{
 const btn=$('#googleSignIn'),error=$('#authError');
 btn.disabled=true;error.textContent='';
 try{
  const redirectTo=isNative?NATIVE_AUTH_CALLBACK:window.location.href.split('#')[0];
  const {data,error:oauthError}=await sb.auth.signInWithOAuth({
   provider:'google',
   options:{redirectTo,skipBrowserRedirect:isNative}
  });
  if(oauthError)throw oauthError;
  if(isNative){
   if(!data?.url)throw new Error('لم يُرجع مزود تسجيل الدخول رابط المصادقة');
   await Browser.open({url:data.url});
  }
 }catch(err){error.textContent=err.message||'تعذر بدء التسجيل عبر Google';btn.disabled=false}
});
$('#profileButton').addEventListener('click',async()=>{if(sb)await sb.auth.signOut();state.user=null;state.accounts=[];state.merchant=null;render();notify('تم تسجيل الخروج')});
if(sb)sb.auth.onAuthStateChange((_event,session)=>{state.user=session?.user||null;refresh()});

async function handleNativeAuthUrl(rawUrl){
 if(!isNative||!rawUrl)return;
 let callback;
 try{callback=new URL(rawUrl)}catch{return}
 if(callback.protocol!=='com.wathaq.app:'||callback.hostname!=='auth'||callback.pathname!=='/callback')return;
 const oauthError=callback.searchParams.get('error_description')||callback.searchParams.get('error');
 if(oauthError){$('#authError').textContent=oauthError;$('#googleSignIn').disabled=false;return}
 const code=callback.searchParams.get('code');
 if(!code){$('#authError').textContent='لم يصل رمز التحقق من Google. حاول تسجيل الدخول مجدداً.';$('#googleSignIn').disabled=false;return}
 const {error}=await sb.auth.exchangeCodeForSession(code);
 if(error)throw error;
 await Browser.close().catch(()=>{});
 if(dialog.open)dialog.close();
 notify('تم تسجيل الدخول بنجاح');
 await refresh();
}
if(isNative){
 App.addListener('appUrlOpen',event=>{
  handleNativeAuthUrl(event.url).catch(err=>{
   console.error('Native OAuth callback failed',err);
   $('#authError').textContent=err.message||'تعذر إكمال تسجيل الدخول';
   $('#googleSignIn').disabled=false;
  });
 });
 App.getLaunchUrl().then(result=>{
  if(result?.url)return handleNativeAuthUrl(result.url);
 }).catch(err=>console.warn('Unable to read native launch URL',err));
}
window.addEventListener('online',()=>$('#connection').innerHTML='<i></i> متصل');
window.addEventListener('offline',()=>$('#connection').innerHTML='<i style="background:#d9a93e"></i> دون اتصال');
$('#scanDialog').addEventListener('close',()=>{if(stopScanner)stopScanner()});
if('serviceWorker' in navigator&&location.protocol==='https:')navigator.serviceWorker.register('./sw.js').catch(err=>console.warn('PWA worker unavailable',err));
refresh();
