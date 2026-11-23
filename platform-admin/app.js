(() => {
  const root = document.getElementById('app');
  const cfg = window.WATHAQ_CONFIG;
  const createClient = window.supabase?.createClient;
  const esc = (value) => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const date = value => value ? new Intl.DateTimeFormat('ar-YE',{dateStyle:'medium'}).format(new Date(value)) : '—';
  const statusNames = {pending:'بانتظار المراجعة',active:'نشط',suspended:'موقوف',rejected:'مرفوض'};
  let sb, currentUser, merchants = [], activeView = 'overview', isSuperAdmin = false, currentPermissions = new Set();

  function toast(message, error=false){
    document.querySelector('.toast')?.remove();
    const el=document.createElement('div');el.className='toast'+(error?' error':'');el.textContent=message;document.body.append(el);
    setTimeout(()=>el.remove(),3600);
  }
  function loading(message='جارٍ التحقق من الصلاحيات…'){
    root.innerHTML='<main class="center-state"><span class="brand-mark">و</span><p>'+esc(message)+'</p></main>';
  }
  function renderLogin(message='لوحة محمية لإدارة منصة وثاق. سجّل الدخول بحساب Google المعتمد كمدير منصة.'){
    root.innerHTML='<main class="center-state"><section class="login-card"><span class="brand-mark">و</span><h1>إدارة وثاق</h1><p>'+esc(message)+'</p><button id="google-login" class="primary-btn">المتابعة باستخدام Google</button><p class="small">الدخول لا يمنح الصلاحيات تلقائياً؛ يجب اعتماد الحساب كمدير أعلى أو تعيينه ضمن مشغّلي المنصة.</p></section></main>';
    document.getElementById('google-login').addEventListener('click',async()=>{
      const redirectTo=window.location.href.split('#')[0];
      const {error}=await sb.auth.signInWithOAuth({provider:'google',options:{redirectTo}});
      if(error)toast(error.message,true);
    });
  }
  function renderDenied(){
    root.innerHTML='<main class="center-state"><section class="denied-card"><span class="brand-mark">و</span><h1>لا توجد صلاحية إدارة</h1><p>هذا الحساب غير مسجل كمدير أعلى ولا يملك عضوية مشغّل نشطة في منصة وثاق.</p><p class="small">'+esc(currentUser?.email||'')+'</p><button id="signout" class="ghost-btn">تسجيل الخروج</button></section></main>';
    document.getElementById('signout').addEventListener('click',()=>sb.auth.signOut());
  }
  function shell(){
    root.innerHTML=`<div class="admin-layout">
      <aside class="sidebar">
        <div class="brand"><span class="brand-mark">و</span><div><strong>وِثاق</strong><span>إدارة المنصة · CORE</span></div></div>
        <nav class="nav-list" aria-label="القائمة الرئيسية">
          <button class="nav-btn active" data-view="overview"><span class="nav-icon">⌂</span>الرئيسية</button>
          <button class="nav-btn" data-view="merchants"><span class="nav-icon">▦</span>المتاجر</button>
          <button class="nav-btn" data-view="users"><span class="nav-icon">♙</span>المستخدمون</button>
          <button class="nav-btn" data-view="staff"><span class="nav-icon">♧</span>موظفو المتاجر</button>
          <button class="nav-btn" data-view="loyalty"><span class="nav-icon">◇</span>نظام الولاء</button>
          <button class="nav-btn" data-view="qr-factory"><span class="nav-icon">▦</span>مصنع الباركودات</button>
          <button class="nav-btn" data-view="audit"><span class="nav-icon">≋</span>سجل التدقيق</button>
          <button class="nav-btn" data-view="analytics"><span class="nav-icon">▤</span>التقارير والتحليلات</button>
          <button class="nav-btn" data-view="operators"><span class="nav-icon">♙</span>مديرو المنصة</button>
          <button class="nav-btn" data-view="roadmap"><span class="nav-icon">⚙</span>الإدارة المتقدمة</button>
        </nav>
        <div class="sidebar-foot">وصول مقيد بالدور والصلاحيات المسجلة في قاعدة البيانات. تُنفّذ العمليات الحساسة عبر دوال خادمية محمية.</div>
      </aside>
      <main class="main-area">
        <header class="topbar"><div><div class="eyebrow">WATHAQ · PLATFORM CONTROL</div><h1 class="page-title" id="page-title">نظرة عامة</h1></div>
          <div class="user-chip"><span class="avatar">و</span><div><b>${esc(currentUser?.email||'مدير المنصة')}</b><small>${isSuperAdmin?"مدير أعلى":"مشغّل منصة معتمد"}</small></div><button id="signout" class="ghost-btn">خروج</button></div>
        </header>
        <div id="view-content"><div class="center-state">جارٍ تحميل البيانات…</div></div>
        <div class="footer-note">WATHAQ-CORE · لا تُنفّذ العمليات المالية من لوحة الإدارة مباشرةً.</div>
      </main>
    </div>`;
    document.getElementById('signout').addEventListener('click',()=>sb.auth.signOut());
    root.querySelectorAll('[data-view]').forEach(b=>b.addEventListener('click',()=>showView(b.dataset.view)));
    const firstView=isSuperAdmin?'overview':['analytics','merchants','users','staff','loyalty','audit'].find(v=>viewAllowed(v))||'overview';
    root.querySelectorAll('[data-view]').forEach(b=>{b.hidden=!viewAllowed(b.dataset.view);});
    showView(firstView);
  }
  async function count(table){
    const {count,error}=await sb.from(table).select('*',{count:'exact',head:true});
    if(error)throw error;return count??0;
  }
  async function loadStats(){
    const {data,error}=await sb.rpc('admin_get_platform_stats');
    if(error)throw error;
    return [{label:'إجمالي المتاجر',value:data?.merchants},{label:'حسابات الولاء',value:data?.loyalty_accounts},{label:'حركات دفتر الولاء',value:data?.loyalty_ledger},{label:'أحداث التدقيق',value:data?.audit_events}];
  }
  function statsHtml(stats){return '<div class="grid-stats">'+stats.map(x=>'<article class="stat-card"><div class="label">'+esc(x.label)+'</div><div class="value">'+(x.value===null||x.value===undefined?'—':Number(x.value).toLocaleString('en-US'))+'</div></article>').join('')+'</div>';}
  async function loadMerchants(){
    const {data,error}=await sb.rpc('admin_list_merchants',{p_search:null,p_limit:200});
    if(error)throw error;merchants=data||[];
  }
  function merchantRows(list){
    if(!list.length)return '<tr><td colspan="5"><div class="empty-state">لا توجد متاجر تطابق البحث.</div></td></tr>';
    return list.map(m=>`<tr><td><b>${esc(m.name)}</b><div class="small muted">${esc(m.slug)}</div></td><td>${esc(m.category||'—')} · ${esc(m.city||'—')}</td><td><span class="status ${esc(m.status)}">${esc(statusNames[m.status]||m.status)}</span></td><td>${date(m.created_at)}</td><td><div class="row-actions">${currentPermissions.has('merchants.status.manage')?(m.status!=='active'?'<button class="primary-btn" data-status="active" data-id="'+esc(m.id)+'">اعتماد/تفعيل</button>':'')+(m.status!=='suspended'?'<button class="ghost-btn" data-status="suspended" data-id="'+esc(m.id)+'">إيقاف</button>':'')+(m.status!=='rejected'&&m.status!=='active'?'<button class="danger-btn" data-status="rejected" data-id="'+esc(m.id)+'">رفض</button>':''):'—'}</div></td></tr>`).join('');
  }
  async function renderOverview(){
    const host=document.getElementById('view-content');host.innerHTML='<div class="center-state">جارٍ تحميل المؤشرات…</div>';
    try{
      const stats=await loadStats();
      let merchantPanel='';
      if(currentPermissions.has('merchants.read')){
        await loadMerchants();
        merchantPanel='<section class="panel"><div class="panel-head"><div><h2>طلبات المتاجر الأخيرة</h2><div class="panel-subtitle">عرض المتاجر وفق صلاحيات الحساب</div></div><button class="ghost-btn" data-goto="merchants">عرض كل المتاجر</button></div><div class="table-wrap"><table><thead><tr><th>المتجر</th><th>التصنيف والموقع</th><th>الحالة</th><th>تاريخ الإنشاء</th><th>الإجراء</th></tr></thead><tbody>'+merchantRows(merchants.slice(0,6))+'</tbody></table></div></section>';
      }
      host.innerHTML=statsHtml(stats)+merchantPanel+'<section class="panel"><div class="notice">تنبيه أمني: لا يمكن للوحة تعديل أرصدة العملاء أو دفتر الحركات أو الرموز مباشرةً. العمليات الحساسة محمية في قاعدة البيانات.</div></section>';
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
  async function renderUsers(){
    const host=document.getElementById('view-content');
    host.innerHTML='<div class="center-state">جارٍ تحميل دليل المستخدمين…</div>';
    const renderRows=rows=>rows.length?rows.map(u=>'<tr><td><b>'+esc(u.full_name||'بدون اسم')+'</b></td><td dir="ltr">'+esc(u.user_id)+'</td><td>'+esc(u.preferred_locale||'—')+'</td><td>'+date(u.created_at)+'</td></tr>').join(''):'<tr><td colspan="4"><div class="empty-state">لا توجد ملفات مستخدمين تطابق البحث.</div></td></tr>';
    try{
      const {data,error}=await sb.rpc('admin_list_user_profiles',{p_search:null,p_limit:100,p_offset:0});
      if(error)throw error;
      host.innerHTML='<section class="panel"><div class="panel-head"><div><h2>دليل المستخدمين</h2><div class="panel-subtitle">عرض محدود لملفات المستخدمين · حتى 100 سجل · دون البريد أو بيانات الدخول</div></div><div class="toolbar"><input id="user-search" class="search-input" placeholder="ابحث بالاسم أو معرّف المستخدم"><button id="user-search-btn" class="ghost-btn">بحث</button></div></div><div class="table-wrap"><table><thead><tr><th>الاسم</th><th>معرّف المستخدم</th><th>اللغة</th><th>تاريخ التسجيل</th></tr></thead><tbody id="user-rows">'+renderRows(data||[])+'</tbody></table></div><div class="panel-subtitle">النتائج المعروضة: '+(data||[]).length+'</div></section><section class="panel"><div class="notice">هذا القسم للقراءة فقط. إدارة أدوار المديرين وحالة حسابات الدخول تحتاج صلاحيات خادمية مستقلة واختبارات إضافية، ولن تُتاح من المتصفح.</div></section>';
      const input=host.querySelector('#user-search');
      const runSearch=async()=>{
        const button=host.querySelector('#user-search-btn');button.disabled=true;
        const {data:rows,error:searchError}=await sb.rpc('admin_list_user_profiles',{p_search:input.value.trim()||null,p_limit:100,p_offset:0});
        if(searchError){toast('تعذر البحث عن المستخدمين: '+searchError.message,true);button.disabled=false;return;}
        host.querySelector('#user-rows').innerHTML=renderRows(rows||[]);
        host.querySelector('.panel-subtitle:last-child').textContent='النتائج المعروضة: '+(rows||[]).length;
        button.disabled=false;
      };
      host.querySelector('#user-search-btn').addEventListener('click',runSearch);
      input.addEventListener('keydown',event=>{if(event.key==='Enter')runSearch();});
    }catch(e){host.innerHTML='<div class="notice error">تعذر تحميل دليل المستخدمين: '+esc(e.message)+'</div>';}
  }
  async function renderStaff(){
    const host=document.getElementById('view-content');
    host.innerHTML='<div class="center-state">جارٍ تحميل عضويات موظفي المتاجر…</div>';
    const rowsHtml=rows=>rows.length?rows.map(x=>'<tr><td><b>'+esc(x.merchant_name)+'</b><div class="small muted" dir="ltr">'+esc(x.merchant_id)+'</div></td><td dir="ltr">'+esc(x.user_id)+'</td><td>'+esc(x.role)+'</td><td>'+esc((x.permissions||[]).join('، ')||'لا توجد صلاحيات إضافية')+'</td><td><span class="status '+(x.is_active?'active':'suspended')+'">'+(x.is_active?'نشط':'غير نشط')+'</span></td><td>'+date(x.created_at)+'</td><td>'+(x.role==='owner'?'<span class="small muted">محمي</span>':currentPermissions.has('staff.status.manage')?'<button class="ghost-btn staff-toggle" data-merchant="'+esc(x.merchant_id)+'" data-user="'+esc(x.user_id)+'" data-active="'+(!x.is_active)+'">'+(x.is_active?'إيقاف':'تفعيل')+'</button>':'—')+'</td></tr>').join(''):'<tr><td colspan="7"><div class="empty-state">لا توجد عضويات موظفين تطابق البحث.</div></td></tr>';
    try{
      const {data,error}=await sb.rpc('admin_list_merchant_staff',{p_search:null,p_limit:200,p_offset:0});
      if(error)throw error;
      const rows=data||[];
      const canManageInvites=currentPermissions.has('staff.invites.manage');
      const inviteResult=canManageInvites?await sb.rpc('admin_list_merchant_invites',{p_merchant_id:null,p_limit:100}):{data:[],error:null};
      const merchantResult=await sb.rpc('admin_list_merchants',{p_search:null,p_limit:200});
      const invites=inviteResult.data||[],inviteError=inviteResult.error,activeMerchants=merchantResult.data||[],merchantError=merchantResult.error;
      if(inviteError)throw inviteError;
      if(merchantError)throw merchantError;
      const inviteRows=(invites||[]).map(i=>{
        const state=i.accepted_at?'مقبولة':i.revoked_at?'ملغاة':new Date(i.expires_at)<=new Date()?'منتهية':'بانتظار الاستخدام';
        const canRevoke=!i.accepted_at&&!i.revoked_at&&new Date(i.expires_at)>new Date();
        return '<tr><td><b>'+esc(i.merchant_name)+'</b></td><td dir="ltr">'+esc(i.phone_e164)+'</td><td>'+esc((i.permissions||[]).join('، '))+'</td><td>'+state+'</td><td>'+date(i.expires_at)+'</td><td>'+(canRevoke?'<button class="danger-btn invite-revoke" data-id="'+esc(i.invite_id)+'">إلغاء الدعوة</button>':'—')+'</td></tr>';
      }).join('')||'<tr><td colspan="6"><div class="empty-state">لا توجد دعوات مسجلة.</div></td></tr>';
      const invitePanel=canManageInvites?'<section class="panel"><div class="panel-head"><div><h2>دعوة موظف متجر</h2><div class="panel-subtitle">إنشاء رمز دعوة صالح لمدة 48 ساعة، مرتبط برقم الهاتف والصلاحيات المحددة.</div></div></div>'+
        '<div class="toolbar"><select id="invite-merchant" class="search-input"><option value="">اختر المتجر النشط</option>'+(activeMerchants||[]).filter(m=>m.status==='active').map(m=>'<option value="'+esc(m.id)+'">'+esc(m.name)+'</option>').join('')+'</select>'+
        '<input id="invite-phone" class="search-input" type="tel" inputmode="tel" placeholder="رقم الهاتف بصيغة دولية +967…">'+
        '<button id="create-invite" class="primary-btn">إنشاء الدعوة</button></div>'+
        '<div class="toolbar" style="margin-top:14px"><label><input type="checkbox" name="invite-permission" value="issue_earn" checked> إصدار نقاط</label><label><input type="checkbox" name="invite-permission" value="confirm_redeem"> تأكيد الاستبدال</label><label><input type="checkbox" name="invite-permission" value="view_analytics"> عرض التحليلات</label></div>'+
        '<div id="invite-result" class="notice hidden" style="margin-top:14px"></div></section>'+
        '<section class="panel"><div class="panel-head"><div><h2>الدعوات الحالية</h2><div class="panel-subtitle">الرمز لا يُخزّن كنص مكشوف؛ يظهر مرة واحدة عند إنشائه.</div></div><button id="refresh-invites" class="ghost-btn">تحديث</button></div><div class="table-wrap"><table><thead><tr><th>المتجر</th><th>الهاتف</th><th>الصلاحيات</th><th>الحالة</th><th>تنتهي في</th><th>إجراء</th></tr></thead><tbody id="invite-rows">'+inviteRows+'</tbody></table></div></section>':'';
      host.innerHTML=invitePanel+'<section class="panel"><div class="panel-head"><div><h2>موظفو المتاجر</h2><div class="panel-subtitle">إدارة حالة عضويات الموظفين مع تسجيل كل تغيير · حتى 200 سجل</div></div><div class="toolbar"><input id="staff-search" class="search-input" placeholder="ابحث باسم المتجر أو المعرّف أو الدور"><button id="staff-search-btn" class="ghost-btn">بحث</button></div></div><div class="table-wrap"><table><thead><tr><th>المتجر</th><th>معرّف الموظف</th><th>الدور</th><th>الصلاحيات</th><th>الحالة</th><th>تاريخ الإضافة</th><th>إجراء</th></tr></thead><tbody id="staff-rows">'+rowsHtml(rows)+'</tbody></table></div><div class="panel-subtitle" id="staff-count">العضويات المعروضة: '+rows.length+'</div></section>'+
        '<section class="panel"><div class="notice">يمكن تفعيل الموظف أو إيقافه من هنا. لا يمكن تغيير عضوية مالك المتجر. كل تغيير ودعوة أو إلغاء يسجل في سجل التدقيق.</div></section>';
      if(canManageInvites)host.querySelector('#create-invite').addEventListener('click',async()=>{
        const merchantId=host.querySelector('#invite-merchant').value;
        const phone=host.querySelector('#invite-phone').value.trim();
        const permissions=[...host.querySelectorAll('[name="invite-permission"]:checked')].map(x=>x.value);
        const button=host.querySelector('#create-invite');
        if(!merchantId||!/^\\+[1-9][0-9]{7,14}$/.test(phone)||!permissions.length){toast('اختر متجراً نشطاً ورقماً دولياً وصلاحية واحدة على الأقل.',true);return;}
        button.disabled=true;
        const {data:created,error:createError}=await sb.rpc('admin_create_merchant_invite',{p_merchant_id:merchantId,p_phone_e164:phone,p_permissions:permissions});
        button.disabled=false;
        if(createError||!created?.ok){toast('تعذر إنشاء الدعوة: '+(createError?.message||created?.error||'unknown_error'),true);return;}
        const result=host.querySelector('#invite-result');
        result.classList.remove('hidden');
        result.innerHTML='<b>تم إنشاء الدعوة.</b> انسخ الرمز وأرسله للموظف؛ لن يظهر مرة أخرى بعد مغادرة هذه الشاشة.<div dir="ltr" style="font-size:22px;font-weight:700;letter-spacing:3px;margin:12px 0">'+esc(created.code)+'</div><button id="copy-invite-code" class="ghost-btn">نسخ رمز الدعوة</button> <span class="small">صالح 48 ساعة</span>';
        result.querySelector('#copy-invite-code').addEventListener('click',async()=>{try{await navigator.clipboard.writeText(created.code);toast('تم نسخ رمز الدعوة.');}catch(_){toast('تعذر النسخ تلقائياً؛ انسخ الرمز يدوياً.',true);}});
        toast('تم إنشاء الدعوة وتسجيلها في سجل التدقيق.');
        await renderStaff();
      });
      if(canManageInvites){
      host.querySelector('#refresh-invites').addEventListener('click',()=>renderStaff());
      host.querySelector('#invite-rows').addEventListener('click',async event=>{
        const button=event.target.closest('.invite-revoke');if(!button)return;
        if(!confirm('هل تريد إلغاء هذه الدعوة؟ لن يتمكن المستلم من استخدامها.'))return;
        button.disabled=true;
        const {data:revoked,error:revokeError}=await sb.rpc('admin_revoke_merchant_invite',{p_invite_id:button.dataset.id});
        if(revokeError||!revoked?.ok){toast('تعذر إلغاء الدعوة: '+(revokeError?.message||revoked?.error||'unknown_error'),true);button.disabled=false;return;}
        toast('تم إلغاء الدعوة وتسجيل الحدث.');
        await renderStaff();
      });
      }
      const input=host.querySelector('#staff-search');
      const search=async()=>{
        const btn=host.querySelector('#staff-search-btn');btn.disabled=true;
        const {data:found,error:e}=await sb.rpc('admin_list_merchant_staff',{p_search:input.value.trim()||null,p_limit:200,p_offset:0});
        if(e){toast('تعذر البحث عن الموظفين: '+e.message,true);btn.disabled=false;return;}
        host.querySelector('#staff-rows').innerHTML=rowsHtml(found||[]);
        host.querySelector('#staff-count').textContent='العضويات المعروضة: '+(found||[]).length;
        btn.disabled=false;
      };
      host.querySelector('#staff-search-btn').addEventListener('click',search);
      input.addEventListener('keydown',event=>{if(event.key==='Enter')search();});
      host.querySelector('#staff-rows').addEventListener('click',async event=>{
        const button=event.target.closest('.staff-toggle');
        if(!button)return;
        const active=button.dataset.active==='true';
        const merchantId=button.dataset.merchant;
        const userId=button.dataset.user;
        button.disabled=true;
        const {data,error:mutationError}=await sb.rpc('admin_set_merchant_member_active',{p_merchant_id:merchantId,p_user_id:userId,p_active:active});
        if(mutationError){toast('تعذر تغيير حالة الموظف: '+mutationError.message,true);button.disabled=false;return;}
        if(!data||data.ok!==true){toast('لم يتم تغيير العضوية: '+(data?.error||'unknown_error'),true);button.disabled=false;return;}
        toast(active?'تم تفعيل عضوية الموظف وتسجيل الحدث.':'تم إيقاف عضوية الموظف وتسجيل الحدث.');
        await search();
      });
    }catch(e){host.innerHTML='<div class="notice error">تعذر تحميل موظفي المتاجر: '+esc(e.message)+'</div>';}
  }
  async function renderLoyalty(){
    const host=document.getElementById('view-content');host.innerHTML='<div class="center-state">جارٍ تحميل نظام الولاء…</div>';
    const stateNames={draft:'مسودة',active:'نشط',paused:'متوقف مؤقتاً',archived:'مؤرشف'};
    try{
      const {data:dashboard,error:dashboardError}=await sb.rpc('admin_get_loyalty_dashboard');
      if(dashboardError)throw dashboardError;
      const accounts=dashboard?.accounts||[],ledger=dashboard?.ledger||[],programs=dashboard?.programs||[],rewards=dashboard?.rewards||[];
      const programRows=(programs||[]).map(p=>{
        const actions=!currentPermissions.has('loyalty.programs.manage')?[]:p.state==='draft'?[['active','تفعيل'],['archived','أرشفة']]:p.state==='active'?[['paused','إيقاف مؤقت'],['archived','أرشفة']]:p.state==='paused'?[['active','إعادة تفعيل'],['archived','أرشفة']]:[];
        return '<tr><td><b>'+esc(p.name)+'</b><div class="small muted" dir="ltr">'+esc(p.merchant_id)+'</div></td><td>'+esc(p.kind==='points'?'نقاط':'أختام')+'</td><td><span class="status '+esc(p.state)+'">'+esc(stateNames[p.state]||p.state)+'</span></td><td>'+date(p.created_at)+'</td><td><div class="row-actions">'+actions.map(a=>'<button class="'+(a[0]==='archived'?'danger-btn':'ghost-btn')+' program-state" data-id="'+esc(p.id)+'" data-state="'+a[0]+'">'+a[1]+'</button>').join('')+'</div></td></tr>';
      }).join('')||'<tr><td colspan="5"><div class="empty-state">لا توجد برامج ولاء.</div></td></tr>';
      const rewardRows=(rewards||[]).map(r=>'<tr><td><b>'+esc(r.title)+'</b><div class="small muted">'+esc(r.merchant_name)+' · '+esc(r.program_name)+'</div></td><td>'+(r.points_cost!==null?Number(r.points_cost).toLocaleString('en-US')+' نقطة':Number(r.stamps_cost).toLocaleString('en-US')+' ختم')+'</td><td>'+(r.stock_quantity===null?'غير محدود':Number(r.stock_quantity).toLocaleString('en-US'))+'</td><td><span class="status '+(r.is_active?'active':'suspended')+'">'+(r.is_active?'نشطة':'متوقفة')+'</span></td><td>'+(currentPermissions.has('loyalty.rewards.manage')?'<button class="ghost-btn reward-toggle" data-id="'+esc(r.reward_id)+'" data-active="'+(!r.is_active)+'">'+(r.is_active?'إيقاف':'تفعيل')+'</button>':'—')+'</td></tr>').join('')+'</tbody></table></div></section><section class="panel"><div class="panel-head"><h2>أحدث حسابات الولاء</h2></div><div class="table-wrap"><table><thead><tr><th>معرّف الحساب</th><th>رصيد النقاط</th><th>رصيد الأختام</th><th>تاريخ الانضمام</th></tr></thead><tbody>'+(accounts||[]).map(x=>'<tr><td>'+esc(x.id.slice(0,8))+'…</td><td>'+Number(x.points_balance).toLocaleString('en-US')+'</td><td>'+Number(x.stamps_balance).toLocaleString('en-US')+'</td><td>'+date(x.joined_at)+'</td></tr>').join('')+'</tbody></table></div></section>';
      const rewardPanel='<section class="panel"><div class="panel-head"><div><h2>المكافآت</h2><div class="panel-subtitle">تفعيل أو إيقاف المكافآت دون تعديل تكلفتها أو مخزونها.</div></div></div><div class="table-wrap"><table><thead><tr><th>المكافأة والمتجر</th><th>التكلفة</th><th>المخزون</th><th>الحالة</th><th>الإجراء</th></tr></thead><tbody>'+rewardRows+'</tbody></table></div></section>';
      host.querySelector('#program-rows').closest('.panel').insertAdjacentHTML('afterend',rewardPanel);
      host.querySelector('.reward-toggle')?.closest('tbody')?.addEventListener('click',async event=>{
        const button=event.target.closest('.reward-toggle');if(!button)return;
        const active=button.dataset.active==='true';
        if(!confirm(active?'تأكيد تفعيل المكافأة؟ يجب أن يكون المتجر والبرنامج نشطين.':'تأكيد إيقاف المكافأة؟'))return;
        button.disabled=true;
        const {data,error}=await sb.rpc('admin_set_reward_active',{p_reward_id:button.dataset.id,p_active:active});
        if(error||!data?.ok){toast('لم يتم تغيير حالة المكافأة: '+(error?.message||data?.error||'تعذر التنفيذ'),true);button.disabled=false;return;}
        toast(active?'تم تفعيل المكافأة.':'تم إيقاف المكافأة.');
        await renderLoyalty();
      });
      host.querySelector('#program-rows').addEventListener('click',async event=>{
        const button=event.target.closest('.program-state');if(!button)return;
        const next=button.dataset.state;
        const label=stateNames[next]||next;
        if(!confirm('تأكيد تغيير حالة البرنامج إلى «'+label+'»؟ سيتم تسجيل العملية في سجل التدقيق.'))return;
        button.disabled=true;
        const {data,error}=await sb.rpc('admin_set_loyalty_program_state',{p_program_id:button.dataset.id,p_state:next});
        if(error||!data?.ok){toast('لم يتم تغيير حالة البرنامج: '+(error?.message||data?.error||'تعذر تنفيذ العملية'),true);button.disabled=false;return;}
        toast('تم تحديث حالة البرنامج وتسجيل الحدث.');
        await renderLoyalty();
      });
    }catch(e){host.innerHTML='<div class="notice error">تعذر قراءة بيانات الولاء: '+esc(e.message)+'</div>';}
  }
  async function renderQrFactory(){
    const host=document.getElementById('view-content');
    host.innerHTML='<div class="center-state">جارٍ تحميل مصنع الباركودات…</div>';
    try{
      const [{data:dashboard,error:dashError},{data:merchantList,error:merchantError},{data:batches,error:batchError}]=await Promise.all([
        sb.rpc('admin_get_loyalty_dashboard'),
        sb.rpc('admin_list_merchants',{p_search:null,p_limit:200}),
        sb.rpc('admin_list_qr_batches',{p_limit:100})
      ]);
      if(dashError)throw dashError;if(merchantError)throw merchantError;if(batchError)throw batchError;
      const activeMerchantIds=new Set((merchantList||[]).filter(m=>m.status==='active').map(m=>m.id));
      const programs=(dashboard?.programs||[]).filter(p=>p.state==='active'&&activeMerchantIds.has(p.merchant_id));
      const options=programs.map(p=>'<option value="'+esc(p.id)+'" data-merchant="'+esc(p.merchant_id)+'" data-kind="'+esc(p.kind)+'">'+esc(p.name)+' · '+(p.kind==='points'?'نقاط':'أختام')+'</option>').join('');
      const rows=(batches||[]).map(b=>{
        const expired=new Date(b.expires_at)<=new Date();
        const state=b.state==='revoked'?'ملغاة':expired?'منتهية':'نشطة';
        return '<tr><td><b>'+esc(b.merchant_name)+'</b><div class="small muted">'+esc(b.program_name)+'</div></td><td>'+esc(b.reward_kind==='points'?'نقاط':'أختام')+'</td><td>'+Number(b.amount).toLocaleString('en-US')+'</td><td>'+Number(b.quantity).toLocaleString('en-US')+'</td><td>'+Number(b.issued_count).toLocaleString('en-US')+' / '+Number(b.consumed_count).toLocaleString('en-US')+'</td><td>'+date(b.expires_at)+'</td><td><span class="status '+(state==='نشطة'?'active':state==='منتهية'?'pending':'suspended')+'">'+state+'</span></td><td><div class="row-actions"><button class="ghost-btn qr-print" data-id="'+esc(b.batch_id)+'">إعادة طباعة</button>'+(b.state==='active'&&!expired?'<button class="danger-btn qr-revoke" data-id="'+esc(b.batch_id)+'">إلغاء</button>':'')+'</div></td></tr>';
      }).join('')||'<tr><td colspan="8"><div class="empty-state">لا توجد دفعات باركودات حتى الآن.</div></td></tr>';
      host.innerHTML=
        '<section class="panel"><div class="panel-head"><div><h2>إنشاء دفعة باركودات</h2><div class="panel-subtitle">رموز QR فريدة من 128 بت، مرتبطة ببرنامج نشط وتُصرف مرة واحدة فقط.</div></div></div>'+
        '<form id="qr-batch-form" class="qr-form">'+
        '<label>برنامج الولاء<select id="qr-program" class="search-input" required><option value="">اختر برنامجاً نشطاً</option>'+options+'</select></label>'+
        '<label>عدد الباركودات<input id="qr-quantity" class="search-input" type="number" min="1" max="1000" value="100" required></label>'+
        '<label>قيمة كل باركود<input id="qr-amount" class="search-input" type="number" min="1" max="1000000" placeholder="مثلاً 50" required></label>'+
        '<label>تاريخ ووقت الانتهاء<input id="qr-expiry" class="search-input" type="datetime-local" required></label>'+
        '<div class="qr-kind-note" id="qr-kind-note">اختر البرنامج لمعرفة نوع الرصيد.</div>'+
        '<div class="qr-actions"><button id="qr-create" class="primary-btn" type="submit" '+(programs.length?'':'disabled')+'>إنشاء الدفعة وتجهيز الطباعة</button></div></form>'+
        '<div class="notice" style="margin-top:14px">لا يتم تخزين الرمز كنص مكشوف: تحفظ قاعدة البيانات بصمة SHA-256 ونسخة مشفرة مخصصة لإعادة الطباعة. إعادة الطباعة تعيد الرموز نفسها ولا تنشئ دفعة جديدة.</div></section>'+
        '<section class="panel"><div class="panel-head"><div><h2>دفعات الباركودات</h2><div class="panel-subtitle">متابعة الصلاحية والاستخدام وإعادة الطباعة أو إلغاء الرموز غير المستخدمة.</div></div><button id="qr-refresh" class="ghost-btn">تحديث</button></div>'+
        '<div class="table-wrap"><table><thead><tr><th>المتجر والبرنامج</th><th>النوع</th><th>قيمة الرمز</th><th>العدد</th><th>متبقي / مستخدم</th><th>ينتهي في</th><th>الحالة</th><th>الإجراءات</th></tr></thead><tbody id="qr-batch-rows">'+rows+'</tbody></table></div></section>';
      const programSelect=host.querySelector('#qr-program');
      const updateKind=()=>{const opt=programSelect.selectedOptions[0];host.querySelector('#qr-kind-note').textContent=opt?.dataset.kind==='points'?'سيضيف كل رمز نقاطاً إلى حساب العميل.':opt?.dataset.kind==='stamps'?'سيضيف كل رمز أختاماً إلى حساب العميل.':'اختر البرنامج لمعرفة نوع الرصيد.';};
      programSelect.addEventListener('change',updateKind);
      host.querySelector('#qr-batch-form').addEventListener('submit',async event=>{
        event.preventDefault();
        const opt=programSelect.selectedOptions[0],programId=programSelect.value;
        const merchantId=opt?.dataset.merchant;
        const quantity=Number(host.querySelector('#qr-quantity').value);
        const amount=Number(host.querySelector('#qr-amount').value);
        const expiryValue=host.querySelector('#qr-expiry').value;
        const expiresAt=expiryValue?new Date(expiryValue).toISOString():null;
        if(!programId||!merchantId||!Number.isInteger(quantity)||quantity<1||quantity>1000||!Number.isInteger(amount)||amount<1||!expiresAt||new Date(expiresAt)<=new Date()){toast('تحقق من البرنامج والعدد والقيمة وموعد الانتهاء.',true);return;}
        if(!confirm('إنشاء '+quantity+' باركود بقيمة '+amount+' '+(opt.dataset.kind==='points'?'نقطة':'ختم')+' لكل رمز؟'))return;
        const printWindow=window.open('about:blank','_blank');
        if(!printWindow){toast('اسمح بالنوافذ المنبثقة لفتح صفحة الطباعة.',true);return;}
        const button=host.querySelector('#qr-create');button.disabled=true;
        const {data,error}=await sb.rpc('admin_create_qr_batch',{p_merchant_id:merchantId,p_program_id:programId,p_quantity:quantity,p_amount:amount,p_expires_at:expiresAt});
        button.disabled=false;
        if(error||!data?.ok){printWindow.close();toast('تعذر إنشاء الدفعة: '+(error?.message||data?.error||'unknown_error'),true);return;}
        toast('تم إنشاء '+data.quantity+' رمزاً فريداً. جارٍ تجهيز صفحة الطباعة.');
        await openQrPrint(data,printWindow);
        await renderQrFactory();
      });
      host.querySelector('#qr-refresh').addEventListener('click',renderQrFactory);
      host.querySelector('#qr-batch-rows').addEventListener('click',async event=>{
        const printButton=event.target.closest('.qr-print');
        if(printButton){
          const printWindow=window.open('about:blank','_blank');
          if(!printWindow){toast('اسمح بالنوافذ المنبثقة لإعادة الطباعة.',true);return;}
          printButton.disabled=true;
          const {data,error}=await sb.rpc('admin_get_qr_batch_print_data',{p_batch_id:printButton.dataset.id});
          printButton.disabled=false;
          if(error){printWindow.close();toast('تعذرت إعادة الطباعة: '+error.message,true);return;}
          await openQrPrint(data,printWindow);return;
        }
        const revokeButton=event.target.closest('.qr-revoke');
        if(revokeButton){
          if(!confirm('إلغاء جميع الرموز غير المستخدمة في هذه الدفعة؟ لا يمكن التراجع عن الإلغاء.'))return;
          revokeButton.disabled=true;
          const {data,error}=await sb.rpc('admin_revoke_qr_batch',{p_batch_id:revokeButton.dataset.id});
          if(error||!data?.ok){toast('تعذر إلغاء الدفعة: '+(error?.message||data?.error||'unknown_error'),true);revokeButton.disabled=false;return;}
          toast('تم إلغاء الرموز غير المستخدمة.');await renderQrFactory();
        }
      });
    }catch(e){host.innerHTML='<div class="notice error">تعذر تحميل مصنع الباركودات: '+esc(e.message)+'</div>';}
  }

  async function openQrPrint(batch,printWindow){
    if(!printWindow||printWindow.closed){toast('تعذر فتح نافذة الطباعة.',true);return;}
    const safe=JSON.stringify(batch).replace(/</g,'\\u003c');
    const kind=batch.kind==='points'?'نقطة':'ختم';
    printWindow.document.open();
    printWindow.document.write('<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>باركودات وثاق</title><style>'+
      'body{font-family:Arial,sans-serif;color:#142033;margin:12mm}.head{display:flex;justify-content:space-between;border-bottom:2px solid #c9a34a;padding-bottom:10px;margin-bottom:12px}.head h1{margin:0 0 5px;font-size:20px}.meta{font-size:12px;color:#46556a;line-height:1.8}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:7mm}.card{border:1px solid #cbd3df;border-radius:8px;padding:5mm;text-align:center;break-inside:avoid;page-break-inside:avoid;min-height:48mm}.card img{width:30mm;height:30mm;display:block;margin:0 auto 3mm}.serial{font-size:10px;color:#667085}.amount{font-weight:bold;font-size:13px;margin:2mm 0}.expiry{font-size:10px;color:#667085}@page{size:A4;margin:10mm}@media print{body{margin:0}.card{border-color:#aeb8c6}}'+
      '</style><script src="https://cdn.jsdelivr.net/npm/qrcode@1.5.4/build/qrcode.min.js"></script></head><body><div class="head"><div><h1>وِثاق · باركودات الولاء</h1><div class="meta">دفعة: '+String(batch.batch_id||'')+'<br>النوع: '+kind+' · القيمة: '+Number(batch.amount)+' لكل رمز<br>الانتهاء: '+new Date(batch.expires_at).toLocaleString('ar-YE')+'</div></div><strong>WATHAQ</strong></div><div id="grid" class="grid"></div><script>const batch='+safe+';const grid=document.getElementById("grid");Promise.all((batch.codes||[]).map(async item=>{const card=document.createElement("div");card.className="card";const img=document.createElement("img");img.src=await QRCode.toDataURL(item.code,{width:300,margin:1,errorCorrectionLevel:"M"});const serial=document.createElement("div");serial.className="serial";serial.textContent="WQ-"+String(item.serial).padStart(4,"0");const amount=document.createElement("div");amount.className="amount";amount.textContent=batch.amount+" '+kind+'";const expiry=document.createElement("div");expiry.className="expiry";expiry.textContent="صالح حتى "+new Date(batch.expires_at).toLocaleDateString("ar-YE");card.append(img,serial,amount,expiry);grid.append(card);})).then(()=>{document.title="WATHAQ-QR-"+batch.batch_id;setTimeout(()=>window.print(),500);}).catch(e=>{document.body.innerHTML="تعذر تجهيز الطباعة: "+String(e);});</script></body></html>');
    printWindow.document.close();
  }
  async function renderAnalytics(){
    const host=document.getElementById('view-content');
    host.innerHTML='<div class="center-state">جارٍ إعداد تقرير التحليلات…</div>';
    try{
      const {data,error}=await sb.rpc('admin_get_analytics_report',{p_days:30});
      if(error)throw error;
      const d=data||{};
      const metrics=[
        ['المستخدمون',d.users_total],['المتاجر',d.merchants_total],['المتاجر النشطة',d.merchants_active],
        ['برامج الولاء النشطة',d.programs_active],['المكافآت النشطة',d.rewards_active],['حسابات الولاء',d.loyalty_accounts_total],
        ['نقاط مكتسبة خلال 30 يوماً',d.points_earned_period],['نقاط مستبدلة خلال 30 يوماً',d.points_redeemed_period]
      ];
      const cards='<div class="grid-stats">'+metrics.map(x=>'<article class="stat-card"><div class="label">'+esc(x[0])+'</div><div class="value">'+(x[1]===null||x[1]===undefined?'—':Number(x[1]).toLocaleString('en-US'))+'</div></article>').join('')+'</div>';
      const trend=(d.trend||[]).slice().reverse().map(x=>'<tr><td>'+esc(x.day)+'</td><td>'+Number(x.ledger_entries||0).toLocaleString('en-US')+'</td><td>'+Number(x.points_earned||0).toLocaleString('en-US')+'</td><td>'+Number(x.points_redeemed||0).toLocaleString('en-US')+'</td></tr>').join('')||'<tr><td colspan="4">لا توجد حركات في الفترة.</td></tr>';
      const kinds=(d.ledger_by_kind||[]).map(x=>'<tr><td>'+esc(x.kind)+'</td><td>'+Number(x.entries||0).toLocaleString('en-US')+'</td><td>'+Number(x.points_delta||0).toLocaleString('en-US')+'</td></tr>').join('')||'<tr><td colspan="3">لا توجد بيانات.</td></tr>';
      host.innerHTML=cards+
        '<section class="panel"><div class="panel-head"><div><h2>حركة الولاء اليومية</h2><div class="panel-subtitle">آخر '+Number(d.period_days||30)+' يوماً · دون كشف هوية العملاء</div></div></div><div class="table-wrap"><table><thead><tr><th>اليوم</th><th>عدد الحركات</th><th>نقاط مكتسبة</th><th>نقاط مستبدلة</th></tr></thead><tbody>'+trend+'</tbody></table></div></section>'+
        '<section class="panel"><div class="panel-head"><div><h2>ملخص دفتر الولاء</h2><div class="panel-subtitle">تجميع حسب نوع الحركة خلال الفترة</div></div></div><div class="table-wrap"><table><thead><tr><th>النوع</th><th>عدد الحركات</th><th>صافي النقاط</th></tr></thead><tbody>'+kinds+'</tbody></table></div></section>'+
        '<section class="panel"><div class="notice">هذه تقارير مجمّعة للقراءة فقط. لا تسمح بتعديل أرصدة العملاء أو دفتر الحركات.</div></section>';
    }catch(e){host.innerHTML='<div class="notice error">تعذر تحميل التقارير: '+esc(e.message)+'</div>';}
  }
  async function renderAudit(){
    const host=document.getElementById('view-content');host.innerHTML='<div class="center-state">جارٍ تحميل سجل التدقيق…</div>';
    try{const {data,error}=await sb.rpc('admin_list_platform_audit',{p_limit:100});if(error)throw error;
      host.innerHTML='<section class="panel"><div class="panel-head"><div><h2>سجل التدقيق</h2><div class="panel-subtitle">آخر 100 حدث متاح وفق صلاحيات المدير</div></div></div><div class="table-wrap"><table><thead><tr><th>الحدث</th><th>الكيان</th><th>المعرّف</th><th>التفاصيل</th><th>التاريخ</th></tr></thead><tbody>'+(data||[]).map(x=>'<tr><td>'+esc(x.action)+'</td><td>'+esc(x.entity_type)+'</td><td>'+esc(x.entity_id||'—')+'</td><td>'+esc(JSON.stringify(x.details||{}))+'</td><td>'+date(x.created_at)+'</td></tr>').join('')+'</tbody></table></div></section>';
    }catch(e){host.innerHTML='<div class="notice error">تعذر قراءة سجل التدقيق: '+esc(e.message)+'</div>';}
  }
  async function renderOperators(){
    const host=document.getElementById('view-content');
    if(!isSuperAdmin){host.innerHTML='<div class="notice error">هذه الشاشة مخصصة للمدير الأعلى.</div>';return;}
    host.innerHTML='<div class="center-state">جارٍ تحميل أدوار مشغّلي المنصة…</div>';
    try{
      const [{data:roles,error:rolesError},{data:operators,error:operatorsError}]=await Promise.all([
        sb.rpc('admin_list_platform_roles'),
        sb.rpc('admin_list_platform_operators')
      ]);
      if(rolesError)throw rolesError;if(operatorsError)throw operatorsError;
      const roleOptions=(roles||[]).map(r=>'<option value="'+esc(r.role_key)+'">'+esc(r.name)+' · '+esc(r.role_key)+'</option>').join('');
      const rows=(operators||[]).map(o=>'<tr><td><b>'+esc(o.full_name||'بدون اسم')+'</b><div class="small muted" dir="ltr">'+esc(o.user_id)+'</div></td><td>'+esc(o.role_name)+' <span class="small muted">('+esc(o.role_key)+')</span></td><td><span class="status '+(o.is_active?'active':'suspended')+'">'+(o.is_active?'نشط':'موقوف')+'</span></td><td>'+date(o.created_at)+'</td><td>'+(o.is_active?'<button class="danger-btn operator-disable" data-user="'+esc(o.user_id)+'">إيقاف الصلاحية</button>':'<span class="small muted">موقوف</span>')+'</td></tr>').join('')||'<tr><td colspan="5"><div class="empty-state">لا يوجد مشغّلون مضافون حالياً.</div></td></tr>';
      host.innerHTML='<section class="panel"><div class="panel-head"><div><h2>إضافة أو تحديث مشغّل</h2><div class="panel-subtitle">هذه الوظيفة للمدير الأعلى فقط. استخدم UUID لحساب موجود في وثاق.</div></div></div><form id="operator-form" class="toolbar" style="flex-wrap:wrap"><input id="operator-user-id" class="search-input" style="min-width:260px" placeholder="معرّف المستخدم UUID" required><select id="operator-role" class="search-input" required>'+roleOptions+'</select><label class="small"><input id="operator-active" type="checkbox" checked> تفعيل الصلاحية</label><button class="primary-btn" type="submit">حفظ العضوية</button></form><p class="small muted">لا يمكن تعيين نفسك أو ترقية حساب إلى مدير أعلى من هنا. المدير الأعلى يُدار حصراً عبر قائمة platform_admins.</p></section><section class="panel"><div class="panel-head"><div><h2>مشغّلو المنصة</h2><div class="panel-subtitle">لا تُعرض عناوين البريد أو أرقام الهواتف في هذا الدليل.</div></div><button id="operators-refresh" class="ghost-btn">تحديث</button></div><div class="table-wrap"><table><thead><tr><th>المستخدم</th><th>الدور</th><th>الحالة</th><th>تاريخ الإضافة</th><th>الإجراء</th></tr></thead><tbody>'+rows+'</tbody></table></div></section><section class="panel"><h2>مصفوفة الأدوار</h2><div class="table-wrap"><table><thead><tr><th>الدور</th><th>الصلاحيات الممنوحة</th></tr></thead><tbody>'+(roles||[]).map(r=>'<tr><td><b>'+esc(r.name)+'</b><div class="small muted">'+esc(r.role_key)+'</div></td><td>'+esc((r.permissions||[]).join(' · '))+'</td></tr>').join('')+'</tbody></table></div></section>';
      host.querySelector('#operator-form').addEventListener('submit',async event=>{
        event.preventDefault();
        const userId=host.querySelector('#operator-user-id').value.trim();
        const roleKey=host.querySelector('#operator-role').value;
        const active=host.querySelector('#operator-active').checked;
        if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(userId)){toast('أدخل UUID صحيحاً للمستخدم.',true);return;}
        if(!confirm('تأكيد حفظ دور '+roleKey+' لهذا المستخدم؟'))return;
        const button=event.submitter;button.disabled=true;
        const {data,error}=await sb.rpc('admin_set_platform_operator',{p_user_id:userId,p_role_key:roleKey,p_active:active});
        if(error||!data?.ok){toast('تعذر حفظ العضوية: '+(error?.message||data?.error||'unknown_error'),true);button.disabled=false;return;}
        toast('تم حفظ عضوية المشغّل وتسجيلها في سجل التدقيق.');
        await renderOperators();
      });
      host.querySelector('#operators-refresh').addEventListener('click',renderOperators);
      host.querySelector('tbody')?.addEventListener('click',async event=>{
        const button=event.target.closest('.operator-disable');if(!button)return;
        if(!confirm('تأكيد إيقاف صلاحيات هذا المشغّل؟'))return;
        button.disabled=true;
        const {data,error}=await sb.rpc('admin_disable_platform_operator',{p_user_id:button.dataset.user});
        if(error||!data?.ok){toast('تعذر إيقاف المشغّل: '+(error?.message||data?.error||'unknown_error'),true);button.disabled=false;return;}
        toast('تم إيقاف صلاحيات المشغّل.');
        await renderOperators();
      });
    }catch(e){host.innerHTML='<div class="notice error">تعذر تحميل إدارة المشغّلين: '+esc(e.message)+'</div>';}
  }
  function renderRoadmap(){
    document.getElementById('view-content').innerHTML='<div class="notice warn">لن نعرض هذه الوظائف على أنها جاهزة قبل إضافة واجهات RPC إدارية محمية واختبارها على قاعدة WATHAQ-CORE.</div><div class="section-grid"><article class="feature-card"><h3>دليل المستخدمين والأدوار</h3><p>أُضيف دليل قراءة محدود لملفات المستخدمين. إدارة أدوار المديرين وتغيير الصلاحيات ما زالت تحتاج نموذج RBAC محكماً واختبارات مستقلة.</p><span class="tag">دليل القراءة قيد الاختبار · RBAC لاحقاً</span></article><article class="feature-card"><h3>التجار والموظفون</h3><p>دليل الموظفين، تفعيل وإيقاف العضويات، إنشاء دعوات برموز أحادية العرض، وإلغاء الدعوات مع تسجيل الأحداث.</p><span class="tag">الدعوات وإدارة الحالة متاحتان</span></article><article class="feature-card"><h3>الباقات والاشتراكات</h3><p>لا توجد بعد واجهات تشغيلية مكتملة للباقات والاشتراكات؛ ستُبنى بعد تحديد قواعدها.</p><span class="tag">قيد التخطيط</span></article><article class="feature-card"><h3>الإعدادات العامة</h3><p>إدارة إعدادات المنصة مع سجل تغييرات وتحقق من القيم المسموح بها في قاعدة البيانات.</p><span class="tag">يتطلب تصميم صلاحيات</span></article><article class="feature-card"><h3>التحليلات ومكافحة الاحتيال</h3><p>تقارير تشغيلية ومؤشرات إساءة الاستخدام والتنبيهات، دون تعديل السجلات المالية.</p><span class="tag">قيد التطوير</span></article><article class="feature-card"><h3>تصدير البيانات</h3><p>تصدير محدود ومصرّح به مع سجل تدقيق وإخفاء الحقول الحساسة.</p><span class="tag">قيد التخطيط</span></article></div>';
  }
  function viewAllowed(view){
    if(view==='overview')return isSuperAdmin||currentPermissions.size>0;
    if(view==='operators'||view==='roadmap')return isSuperAdmin;
    if(view==='analytics')return currentPermissions.has('analytics.read');
    if(view==='qr-factory')return isSuperAdmin||currentPermissions.has('loyalty.qr.manage');
    const required={merchants:'merchants.read',users:'users.read',staff:'staff.read',loyalty:'loyalty.read',audit:'audit.read'}[view];
    return !!required&&currentPermissions.has(required);
  }
  async function showView(view){
    if(!viewAllowed(view)){toast('ليس لديك صلاحية لفتح هذا القسم.',true);return;}
    activeView=view;root.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',b.dataset.view===view));
    const titles={overview:'نظرة عامة',merchants:'إدارة المتاجر',users:'المستخدمون',staff:'موظفو المتاجر',loyalty:'نظام الولاء','qr-factory':'مصنع الباركودات',audit:'سجل التدقيق',analytics:'التقارير والتحليلات',operators:'مديرو المنصة',roadmap:'الإدارة المتقدمة'};
    document.getElementById('page-title').textContent=titles[view]||'إدارة وثاق';
    if(view==='overview')await renderOverview();else if(view==='merchants')await renderMerchants();else if(view==='users')await renderUsers();else if(view==='staff')await renderStaff();else if(view==='loyalty')await renderLoyalty();else if(view==='qr-factory')await renderQrFactory();else if(view==='audit')await renderAudit();else if(view==='analytics')await renderAnalytics();else if(view==='operators')await renderOperators();else renderRoadmap();
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
    if(adminError){renderLogin('تعذر التحقق من صلاحيات الحساب. '+adminError.message);return;}
    isSuperAdmin=!!admin;
    const {data:permissions,error:permissionError}=await sb.rpc('admin_get_my_permissions');
    if(permissionError){renderLogin('تعذر تحميل صلاحيات الحساب. '+permissionError.message);return;}
    currentPermissions=new Set(permissions||[]);
    if(!isSuperAdmin&&currentPermissions.size===0){renderDenied();return;}
    shell();
  }
  boot().catch(e=>{root.innerHTML='<main class="center-state"><section class="denied-card"><h1>تعذر فتح لوحة الإدارة</h1><p>'+esc(e.message)+'</p></section></main>';});
})();
