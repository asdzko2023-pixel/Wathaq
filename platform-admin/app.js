(() => {
  const root = document.getElementById('app');
  const cfg = window.WATHAQ_CONFIG;
  const createClient = window.supabase?.createClient;
  const esc = (value) => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const date = value => value ? new Intl.DateTimeFormat('ar-YE',{dateStyle:'medium'}).format(new Date(value)) : '—';
  const statusNames = {pending:'بانتظار المراجعة',active:'نشط',suspended:'موقوف',rejected:'مرفوض'};
  let sb, currentUser, merchants = [], activeView = 'overview';

  function toast(message, error=false){
    document.querySelector('.toast')?.remove();
    const el=document.createElement('div');el.className='toast'+(error?' error':'');el.textContent=message;document.body.append(el);
    setTimeout(()=>el.remove(),3600);
  }
  function loading(message='جارٍ التحقق من الصلاحيات…'){
    root.innerHTML='<main class="center-state"><span class="brand-mark">و</span><p>'+esc(message)+'</p></main>';
  }
  function renderLogin(message='لوحة محمية لإدارة منصة وثاق. سجّل الدخول بحساب Google المعتمد كمدير منصة.'){
    root.innerHTML='<main class="center-state"><section class="login-card"><span class="brand-mark">و</span><h1>إدارة وثاق</h1><p>'+esc(message)+'</p><button id="google-login" class="primary-btn">المتابعة باستخدام Google</button><p class="small">الدخول لا يمنح صلاحية الإدارة؛ يجب أن يكون الحساب مضافاً مسبقاً إلى platform_admins.</p></section></main>';
    document.getElementById('google-login').addEventListener('click',async()=>{
      const redirectTo=window.location.href.split('#')[0];
      const {error}=await sb.auth.signInWithOAuth({provider:'google',options:{redirectTo}});
      if(error)toast(error.message,true);
    });
  }
  function renderDenied(){
    root.innerHTML='<main class="center-state"><section class="denied-card"><span class="brand-mark">و</span><h1>لا توجد صلاحية إدارة</h1><p>تم تسجيل الدخول، لكن هذا الحساب غير مسجل في قائمة مديري منصة وثاق. لا يمكن فتح لوحة الإدارة قبل اعتماد الحساب من مسؤول مخوّل.</p><p class="small">'+esc(currentUser?.email||'')+'</p><button id="signout" class="ghost-btn">تسجيل الخروج</button></section></main>';
    document.getElementById('signout').addEventListener('click',()=>sb.auth.signOut());
  }
  function shell(){
    root.innerHTML=`<div class="admin-layout">
      <aside class="sidebar">
        <div class="brand"><span class="brand-mark">و</span><div><strong>وِثاق</strong><span>إدارة المنصة · CORE</span></div></div>
        <nav class="nav-list" aria-label="القائمة الرئيسية">
          <button class="nav-btn active" data-view="overview"><span class="nav-icon">⌂</span>الرئيسية</button>
          <button class="nav-btn" data-view="merchants"><span class="nav-icon">▦</span>المتاجر</button>
          <button class="nav-btn" data-view="loyalty"><span class="nav-icon">◇</span>نظام الولاء</button>
          <button class="nav-btn" data-view="audit"><span class="nav-icon">≋</span>سجل التدقيق</button>
          <button class="nav-btn" data-view="roadmap"><span class="nav-icon">⚙</span>الإدارة المتقدمة</button>
        </nav>
        <div class="sidebar-foot">وصول مقيد بهوية المدير وسياسات قاعدة البيانات. كل تغيير في حالة المتجر يسجله الخادم في سجل التدقيق.</div>
      </aside>
      <main class="main-area">
        <header class="topbar"><div><div class="eyebrow">WATHAQ · PLATFORM CONTROL</div><h1 class="page-title" id="page-title">نظرة عامة</h1></div>
          <div class="user-chip"><span class="avatar">و</span><div><b>${esc(currentUser?.email||'مدير المنصة')}</b><small>مدير منصة موثّق</small></div><button id="signout" class="ghost-btn">خروج</button></div>
        </header>
        <div id="view-content"><div class="center-state">جارٍ تحميل البيانات…</div></div>
        <div class="footer-note">WATHAQ-CORE · لا تُنفّذ العمليات المالية من لوحة الإدارة مباشرةً.</div>
      </main>
    </div>`;
    document.getElementById('signout').addEventListener('click',()=>sb.auth.signOut());
    root.querySelectorAll('[data-view]').forEach(b=>b.addEventListener('click',()=>showView(b.dataset.view)));
    showView('overview');
  }
  async function count(table){
    const {count,error}=await sb.from(table).select('*',{count:'exact',head:true});
    if(error)throw error;return count??0;
  }
  async function loadStats(){
    const [m,a,l,e]=await Promise.all([count('merchants'),count('loyalty_accounts'),count('loyalty_ledger'),count('audit_events')]);
    return [{label:'إجمالي المتاجر',value:m},{label:'حسابات الولاء',value:a},{label:'حركات دفتر الولاء',value:l},{label:'أحداث التدقيق',value:e}];
  }
  function statsHtml(stats){return '<div class="grid-stats">'+stats.map(x=>'<article class="stat-card"><div class="label">'+esc(x.label)+'</div><div class="value">'+Number(x.value).toLocaleString('en-US')+'</div></article>').join('')+'</div>';}
  async function loadMerchants(){
    const {data,error}=await sb.from('merchants').select('id,name,slug,status,category,city,created_at').order('created_at',{ascending:false}).limit(200);
    if(error)throw error;merchants=data||[];
  }
  function merchantRows(list){
    if(!list.length)return '<tr><td colspan="5"><div class="empty-state">لا توجد متاجر تطابق البحث.</div></td></tr>';
    return list.map(m=>`<tr><td><b>${esc(m.name)}</b><div class="small muted">${esc(m.slug)}</div></td><td>${esc(m.category||'—')} · ${esc(m.city||'—')}</td><td><span class="status ${esc(m.status)}">${esc(statusNames[m.status]||m.status)}</span></td><td>${date(m.created_at)}</td><td><div class="row-actions">${m.status!=='active'?'<button class="primary-btn" data-status="active" data-id="'+esc(m.id)+'">اعتماد/تفعيل</button>':''}${m.status!=='suspended'?'<button class="ghost-btn" data-status="suspended" data-id="'+esc(m.id)+'">إيقاف</button>':''}${m.status!=='rejected'&&m.status!=='active'?'<button class="danger-btn" data-status="rejected" data-id="'+esc(m.id)+'">رفض</button>':''}</div></td></tr>`).join('');
  }
  async function renderOverview(){
    const host=document.getElementById('view-content');host.innerHTML='<div class="center-state">جارٍ تحميل المؤشرات…</div>';
    try{
      const [stats]=await Promise.all([loadStats(),loadMerchants()]);
      host.innerHTML=statsHtml(stats)+'<section class="panel"><div class="panel-head"><div><h2>طلبات المتاجر الأخيرة</h2><div class="panel-subtitle">مراجعة حالة المتاجر عبر صلاحيات WATHAQ-CORE</div></div><button class="ghost-btn" data-goto="merchants">عرض كل المتاجر</button></div><div class="table-wrap"><table><thead><tr><th>المتجر</th><th>التصنيف والموقع</th><th>الحالة</th><th>تاريخ الإنشاء</th><th>الإجراء</th></tr></thead><tbody>'+merchantRows(merchants.slice(0,6))+'</tbody></table></div></section><section class="panel"><div class="notice">تنبيه أمني: لا يمكن للوحة تعديل أرصدة العملاء أو دفتر الحركات أو الرموز مباشرة. تتم عمليات الاكتساب والاستبدال من خلال دوال الخادم المحمية.</div></section>';
      bindMerchantActions(host);
      host.querySelector('[data-goto]')?.addEventListener('click',()=>showView('merchants'));
    }catch(e){host.innerHTML='<div class="notice error">تعذر تحميل مؤشرات المنصة: '+esc(e.message)+'</div>';}
  }
  async function renderMerchants(){
    const host=document.getElementById('view-content');host.innerHTML='<div class="center-state">جارٍ تحميل المتاجر…</div>';
    try{await loadMerchants();host.innerHTML='<section class="panel"><div class="panel-head"><div><h2>إدارة المتاجر</h2><div class="panel-subtitle">حتى 200 متجر في هذه الصفحة</div></div><div class="toolbar"><input id="merchant-search" class="search-input" placeholder="ابحث باسم المتجر أو المدينة"><button id="refresh-merchants" class="ghost-btn">تحديث</button></div></div><div class="table-wrap"><table><thead><tr><th>المتجر</th><th>التصنيف والموقع</th><th>الحالة</th><th>تاريخ الإنشاء</th><th>الإجراءات</th></tr></thead><tbody id="merchant-rows">'+merchantRows(merchants)+'</tbody></table></div></section>';
      const input=host.querySelector('#merchant-search');input.addEventListener('input',()=>{const q=input.value.trim().toLowerCase();const filtered=merchants.filter(m=>[m.name,m.slug,m.city,m.category].some(v=>String(v||'').toLowerCase().includes(q)));host.querySelector('#merchant-rows').innerHTML=merchantRows(filtered);bindMerchantActions(host);});
      host.querySelector('#refresh-merchants').addEventListener('click',()=>renderMerchants());bindMerchantActions(host);
    }catch(e){host.innerHTML='<div class="notice error">تعذر تحميل المتاجر: '+esc(e.message)+'</div>';}
  }
  function bindMerchantActions(host){
    host.querySelectorAll('[data-status][data-id]').forEach(button=>button.addEventListener('click',async()=>{
      const merchant=merchants.find(m=>m.id===button.dataset.id);const next=button.dataset.status;
      if(!merchant)return;
      if(!confirm('تأكيد تغيير حالة «'+merchant.name+'» إلى «'+(statusNames[next]||next)+'»؟ سيتم تسجيل العملية في سجل التدقيق.'))return;
      button.disabled=true;
      const {data,error}=await sb.rpc('admin_set_merchant_status',{p_merchant_id:merchant.id,p_status:next});
      if(error||!data?.ok){toast('لم يتم تغيير الحالة: '+(error?.message||data?.error||'تعذر تنفيذ العملية'),true);button.disabled=false;return;}
      merchant.status=data.status;toast('تم تحديث حالة المتجر وتسجيل الحدث.');
      if(activeView==='overview')renderOverview();else renderMerchants();
    }));
  }
  async function renderLoyalty(){
    const host=document.getElementById('view-content');host.innerHTML='<div class="center-state">جارٍ تحميل نظام الولاء…</div>';
    try{
      const [{data:accounts,error:aErr},{data:ledger,error:lErr},{data:programs,error:pErr}]=await Promise.all([
        sb.from('loyalty_accounts').select('id,points_balance,stamps_balance,joined_at').order('joined_at',{ascending:false}).limit(8),
        sb.from('loyalty_ledger').select('id,kind,points_delta,stamps_delta,created_at,reference').order('created_at',{ascending:false}).limit(12),
        sb.from('loyalty_programs').select('id,name,kind,state,created_at').order('created_at',{ascending:false}).limit(12)
      ]);
      if(aErr)throw aErr;if(lErr)throw lErr;if(pErr)throw pErr;
      host.innerHTML='<div class="notice warn">هذه الشاشة للمتابعة والقراءة فقط. لا تُجرى تعديلات على الأرصدة أو دفتر الحركات من واجهة الإدارة.</div><section class="panel"><div class="panel-head"><h2>البرامج</h2><span class="small muted">'+(programs||[]).length+' حديثة</span></div><div class="table-wrap"><table><thead><tr><th>البرنامج</th><th>النوع</th><th>الحالة</th><th>تاريخ الإنشاء</th></tr></thead><tbody>'+(programs||[]).map(p=>'<tr><td>'+esc(p.name)+'</td><td>'+esc(p.kind==='points'?'نقاط':'أختام')+'</td><td>'+esc(p.state)+'</td><td>'+date(p.created_at)+'</td></tr>').join('')+'</tbody></table></div></section><section class="panel"><div class="panel-head"><h2>أحدث حركات الولاء</h2></div><div class="table-wrap"><table><thead><tr><th>النوع</th><th>تغير النقاط</th><th>تغير الأختام</th><th>المرجع</th><th>التاريخ</th></tr></thead><tbody>'+(ledger||[]).map(x=>'<tr><td>'+esc(x.kind)+'</td><td dir="ltr">'+Number(x.points_delta).toLocaleString('en-US')+'</td><td dir="ltr">'+Number(x.stamps_delta).toLocaleString('en-US')+'</td><td>'+esc(x.reference||'—')+'</td><td>'+date(x.created_at)+'</td></tr>').join('')+'</tbody></table></div></section><section class="panel"><div class="panel-head"><h2>أحدث حسابات الولاء</h2></div><div class="table-wrap"><table><thead><tr><th>معرّف الحساب</th><th>رصيد النقاط</th><th>رصيد الأختام</th><th>تاريخ الانضمام</th></tr></thead><tbody>'+(accounts||[]).map(x=>'<tr><td>'+esc(x.id.slice(0,8))+'…</td><td>'+Number(x.points_balance).toLocaleString('en-US')+'</td><td>'+Number(x.stamps_balance).toLocaleString('en-US')+'</td><td>'+date(x.joined_at)+'</td></tr>').join('')+'</tbody></table></div></section>';
    }catch(e){host.innerHTML='<div class="notice error">تعذر قراءة بيانات الولاء: '+esc(e.message)+'</div>';}
  }
  async function renderAudit(){
    const host=document.getElementById('view-content');host.innerHTML='<div class="center-state">جارٍ تحميل سجل التدقيق…</div>';
    try{const {data,error}=await sb.from('audit_events').select('id,action,entity_type,entity_id,merchant_id,created_at,details').order('created_at',{ascending:false}).limit(100);if(error)throw error;
      host.innerHTML='<section class="panel"><div class="panel-head"><div><h2>سجل التدقيق</h2><div class="panel-subtitle">آخر 100 حدث متاح وفق صلاحيات المدير</div></div></div><div class="table-wrap"><table><thead><tr><th>الحدث</th><th>الكيان</th><th>المعرّف</th><th>التفاصيل</th><th>التاريخ</th></tr></thead><tbody>'+(data||[]).map(x=>'<tr><td>'+esc(x.action)+'</td><td>'+esc(x.entity_type)+'</td><td>'+esc(x.entity_id||'—')+'</td><td>'+esc(JSON.stringify(x.details||{}))+'</td><td>'+date(x.created_at)+'</td></tr>').join('')+'</tbody></table></div></section>';
    }catch(e){host.innerHTML='<div class="notice error">تعذر قراءة سجل التدقيق: '+esc(e.message)+'</div>';}
  }
  function renderRoadmap(){
    document.getElementById('view-content').innerHTML='<div class="notice warn">لن نعرض هذه الوظائف على أنها جاهزة قبل إضافة واجهات RPC إدارية محمية واختبارها على قاعدة WATHAQ-CORE.</div><div class="section-grid"><article class="feature-card"><h3>إدارة المستخدمين والمديرين</h3><p>تتطلب دوال خادم مخصصة لاستعراض الحسابات وإدارة الصلاحيات دون كشف auth.users أو منح الدور من المتصفح.</p><span class="tag">الخطوة التالية · أولوية عالية</span></article><article class="feature-card"><h3>التجار والموظفون</h3><p>إدارة العضويات والدعوات والصلاحيات، مع التحقق من هوية المدير وتسجيل كل تغيير.</p><span class="tag">يتطلب استكمال RPC</span></article><article class="feature-card"><h3>الباقات والاشتراكات</h3><p>لا توجد بعد واجهات تشغيلية مكتملة للباقات والاشتراكات؛ ستُبنى بعد تحديد قواعدها.</p><span class="tag">قيد التخطيط</span></article><article class="feature-card"><h3>الإعدادات العامة</h3><p>إدارة إعدادات المنصة مع سجل تغييرات وتحقق من القيم المسموح بها في قاعدة البيانات.</p><span class="tag">يتطلب تصميم صلاحيات</span></article><article class="feature-card"><h3>التحليلات ومكافحة الاحتيال</h3><p>تقارير تشغيلية ومؤشرات إساءة الاستخدام والتنبيهات، دون تعديل السجلات المالية.</p><span class="tag">قيد التطوير</span></article><article class="feature-card"><h3>تصدير البيانات</h3><p>تصدير محدود ومصرّح به مع سجل تدقيق وإخفاء الحقول الحساسة.</p><span class="tag">قيد التخطيط</span></article></div>';
  }
  async function showView(view){
    activeView=view;root.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',b.dataset.view===view));
    const titles={overview:'نظرة عامة',merchants:'إدارة المتاجر',loyalty:'نظام الولاء',audit:'سجل التدقيق',roadmap:'الإدارة المتقدمة'};
    document.getElementById('page-title').textContent=titles[view]||'إدارة وثاق';
    if(view==='overview')await renderOverview();else if(view==='merchants')await renderMerchants();else if(view==='loyalty')await renderLoyalty();else if(view==='audit')await renderAudit();else renderRoadmap();
  }
  async function boot(){
    if(!createClient||!cfg?.url||!cfg?.key){root.innerHTML='<main class="center-state"><section class="denied-card"><h1>إعداد الاتصال غير مكتمل</h1><p>تعذر تحميل إعداد Supabase العام. راجع app/config.js.</p></section></main>';return;}
    sb=createClient(cfg.url,cfg.key,{auth:{persistSession:true,autoRefreshToken:true,flowType:'pkce'}});
    sb.auth.onAuthStateChange((_event,session)=>{if(!session)renderLogin();});
    const {data,error}=await sb.auth.getSession();if(error){renderLogin(error.message);return;}
    currentUser=data.session?.user;
    if(!currentUser){renderLogin();return;}
    loading();
    const {data:admin,error:adminError}=await sb.from('platform_admins').select('user_id').eq('user_id',currentUser.id).maybeSingle();
    if(adminError){renderLogin('تعذر التحقق من صلاحيات المدير. '+adminError.message);return;}
    if(!admin){renderDenied();return;}
    shell();
  }
  boot().catch(e=>{root.innerHTML='<main class="center-state"><section class="denied-card"><h1>تعذر فتح لوحة الإدارة</h1><p>'+esc(e.message)+'</p></section></main>';});
})();
