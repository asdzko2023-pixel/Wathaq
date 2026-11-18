const { createClient } = window.supabase;
const cfg = window.WATHAQ_CONFIG || {};
const sb = cfg.url && cfg.key ? createClient(cfg.url,cfg.key,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}}) : null;
const $ = (s,r=document)=>r.querySelector(s);
const esc = s => String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const state={view:'customer',user:null,merchant:null,accounts:[],programs:[],rewards:[],ledger:[],otpSent:false};
const app=$('#app'),dialog=$('#authDialog'),toast=$('#toast');
const money=n=>new Intl.NumberFormat('ar-YE',{maximumFractionDigits:0}).format(Number(n||0));
function notify(s){toast.textContent=s;toast.classList.add('show');setTimeout(()=>toast.classList.remove('show'),2600)}
function icon(type){const p={star:'<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3l-5.6 2.9 1.1-6.2L3 9.6l6.2-.9z"/>',store:'<path d="M3 10h18l-2-6H5zM5 10v10h14V10M9 20v-6h6v6"/>',gift:'<path d="M3 10h18v11H3zM2 6h20v4H2zM12 6v15M12 6H8a2 2 0 1 1 2-2c0 1.1 2 2 2 2zm0 0h4a2 2 0 1 0-2-2c0 1.1-2 2-2 2z"/>',thread:'<path d="M4 6c4-4 12-4 16 0M4 18c4 4 12 4 16 0M4 6l16 12M4 18 20 6"/>'};return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'+(p[type]||p.thread)+'</svg>'}
function top(t,s){return '<div class="section-head"><div><h2>'+t+'</h2><p>'+s+'</p></div></div>'}
function hero(e,t,d,a=''){return '<section class="hero"><div class="hero-content"><div class="eyebrow">'+e+'</div><h1>'+t+'</h1><p>'+d+'</p><div class="hero-actions">'+a+'</div></div><div class="hero-art">'+icon('thread')+'</div></section>'}
function render(){
 $('#authButton').hidden=!!state.user;$('#profileButton').hidden=!state.user;
 if(state.user)$('#profileButton').textContent=(state.user.phone||state.user.email||'و').slice(-1).toUpperCase();
 document.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',b.dataset.view===state.view));
 if(state.view==='customer')renderCustomer();else if(state.view==='merchant')renderMerchant();else renderStaff();
}
async function customerData(){
 const [a,p,r,t]=await Promise.all([
 sb.from('loyalty_accounts').select('id,points_balance,stamps_balance,joined_at,merchant_id,program_id,merchants(name,category),loyalty_programs(name,kind,stamp_goal)').eq('customer_id',state.user.id).order('last_activity_at',{ascending:false}),
 sb.from('loyalty_programs').select('id,name,kind,description,stamp_goal,merchant_id,merchants(name,category)').eq('state','active').limit(30),
 sb.from('loyalty_ledger').select('id,kind,points_delta,stamps_delta,created_at,reference,merchants(name)').eq('customer_id',state.user.id).order('created_at',{ascending:false}).limit(12)
 ]);
 if(a.error)throw a.error;if(p.error)throw p.error;if(t.error)throw t.error;
 state.accounts=a.data||[];state.programs=p.data||[];state.ledger=t.data||[];
}
function renderCustomer(){
 if(!state.user){app.innerHTML=hero('نظام ولاء بتجربة مختلفة','كل زيارة تستحق أن تُكافأ.','اكتشف برامج الولاء حولك، واجمع نقاطك وأختامك، واستبدلها بمكافآت حقيقية من متاجرك المفضلة.','<button class="btn btn-gold" data-login>ابدأ الآن</button><span class="tag gold">مصمم ليكافئ ولاءك</span>')+top('كيف يعمل وِثاق؟','ثلاث خطوات بسيطة، وتجربة واحدة متصلة.')+'<div class="grid"><article class="panel"><div class="store-icon">'+icon('store')+'</div><h3>اكتشف المتاجر</h3><p class="muted">تعرّف على العلامات التجارية وبرامج الولاء النشطة.</p></article><article class="panel"><div class="store-icon">'+icon('star')+'</div><h3>اجمع المكافآت</h3><p class="muted">أكسب نقاطاً أو أختاماً مع كل عملية شراء مؤهلة.</p></article><article class="panel"><div class="store-icon">'+icon('gift')+'</div><h3>استبدل بذكاء</h3><p class="muted">حوّل رصيدك إلى مكافآت من المتاجر المشاركة.</p></article></div>';return}
 app.innerHTML='<div class="eyebrow">مساحة العميل · '+esc(state.user.phone||state.user.email||'حسابك')+'</div>'+hero('أهلاً بك في نسيج الولاء','ولاؤك له قيمة.','كل نقطة تحمل قصة زيارة، وكل ختم يقربك من مكافأة تستحقها.','<span class="tag gold">حساب موثّق</span><button class="btn btn-soft" data-refresh>تحديث البيانات</button>')+top('رصيدك ومشاركاتك','ملخص حسابات الولاء النشطة لديك.')+'<div class="grid">'+(state.accounts.length?state.accounts.map(a=>'<article class="panel balance-card"><div class="panel-head"><div><span class="tag">'+esc(a.loyalty_programs?.name||'برنامج ولاء')+'</span><h3 style="margin-top:12px">'+esc(a.merchants?.name||'المتجر')+'</h3></div><div class="store-icon">'+icon('star')+'</div></div><div class="metric">'+(a.loyalty_programs?.kind==='points'?money(a.points_balance)+' نقطة':money(a.stamps_balance)+' ختم')+'</div><div class="metric-label">الرصيد المتاح · منذ '+new Date(a.joined_at).toLocaleDateString('ar')+'</div><div class="actions"><button class="btn btn-gold" data-earn="'+a.program_id+'">إظهار رمز الاكتساب</button></div></article>').join(''):'<div class="empty"><b>لا توجد بطاقات ولاء بعد</b>انضم إلى أحد البرامج النشطة بالأسفل.</div>')+'</div>'+top('برامج يمكنك الانضمام إليها','اختر البرنامج المناسب وابدأ جمع المكافآت.')+'<div class="grid">'+(state.programs.length?state.programs.map(p=>'<article class="panel"><div class="panel-head"><span class="tag gold">'+(p.kind==='points'?'برنامج نقاط':'برنامج أختام')+'</span><div class="store-icon">'+icon('store')+'</div></div><h3>'+esc(p.name)+'</h3><p class="muted">'+esc(p.merchants?.name||'متجر مشارك')+'</p><p class="muted">'+esc(p.description||'انضم واكتشف مكافآت هذا البرنامج.')+'</p><button class="btn btn-outline" data-join="'+p.id+'">انضم إلى البرنامج</button></article>').join(''):'<div class="empty">لا توجد برامج نشطة حالياً.</div>')+'</div>'+top('مكافآت بانتظارك','استبدل رصيدك بمكافآت حقيقية من متاجرك.')+'<div class="grid">'+(state.rewards.length?state.rewards.map(r=>'<article class="panel"><span class="tag gold">'+(r.loyalty_programs?.kind==='points'?'مكافأة نقاط':'مكافأة أختام')+'</span><h3 style="margin-top:14px">'+esc(r.title)+'</h3><p class="muted">'+esc(r.description||r.loyalty_programs?.name||'مكافأة من المتجر')+'</p><div class="metric" style="font-size:22px">'+money(r.points_cost||r.stamps_cost)+' '+(r.loyalty_programs?.kind==='points'?'نقطة':'ختم')+'</div><button class="btn btn-gold" data-redeem="'+r.id+'" data-account="'+(state.accounts.find(a=>a.program_id===r.program_id)?.id||'')+'">طلب الاستبدال</button></article>').join(''):'<div class="empty">لا توجد مكافآت منشورة حالياً.</div>')+'</div>'+top('آخر الحركات','كل عملية مسجلة في دفتر الولاء.')+'<div class="panel table-wrap"><table class="table"><thead><tr><th>العملية</th><th>المتجر</th><th>التغيير</th><th>التاريخ</th></tr></thead><tbody>'+(state.ledger.length?state.ledger.map(t=>'<tr><td>'+({earn:'اكتساب',redeem:'استبدال',adjustment:'تعديل',reversal:'عكس عملية',expiry:'انتهاء'}[t.kind]||t.kind)+'</td><td>'+esc(t.merchants?.name||'—')+'</td><td>'+((t.points_delta>0?'+':'')+money(t.points_delta)+' نقطة · '+(t.stamps_delta>0?'+':'')+money(t.stamps_delta)+' ختم')+'</td><td>'+new Date(t.created_at).toLocaleDateString('ar')+'</td></tr>').join(''):'<tr><td colspan="4" class="muted">لا توجد حركات مسجلة.</td></tr>')+'</tbody></table></div>';
}
async function merchantData(){
 const {data,error}=await sb.from('merchants').select('id,name,slug,status,category,city,created_at,loyalty_programs(id,name,kind,state,version),loyalty_accounts(id,points_balance,stamps_balance)').order('created_at',{ascending:false});
 if(error)throw error;state.merchants=data||[];state.merchant=state.merchants[0]||null;
}
function renderMerchant(){
 if(!state.user){app.innerHTML=hero('بوابة الشركاء','حوّل العملاء إلى مجتمع وفيّ.','منصة متكاملة لإدارة برامج الولاء، ومتابعة أداء متجرك، وبناء علاقة طويلة الأمد مع عملائك.','<button class="btn btn-gold" data-login>دخول لوحة التاجر</button>');return}
 if(!state.merchant){app.innerHTML=hero('مساحة التاجر','ابدأ ببناء برنامج ولاء يحمل هوية متجرك.','أنشئ ملف متجرك، ثم أطلق برنامج النقاط أو الأختام خلال دقائق.','<span class="tag gold">حساب جديد</span>')+top('تسجيل متجرك','ستتم مراجعة المتجر قبل تفعيله للعملاء.')+'<div class="panel"><form id="merchantCreate"><div class="form-grid"><div class="field"><label>اسم المتجر</label><input name="name" required minlength="2" placeholder="مثال: مقهى الوِثاق"></div><div class="field"><label>التصنيف</label><select name="category"><option>مطاعم ومقاهي</option><option>ملابس</option><option>عطور وتجميل</option><option>تجزئة</option><option>أخرى</option></select></div><div class="field"><label>المدينة</label><input name="city" placeholder="عدن"></div><div class="field"><label>وصف مختصر</label><input name="description" placeholder="ما الذي يميز متجرك؟"></div></div><button class="btn btn-gold">إنشاء ملف المتجر</button></form></div>';return}
 const m=state.merchant,programs=m.loyalty_programs||[],customers=(m.loyalty_accounts||[]).length,points=(m.loyalty_accounts||[]).reduce((s,a)=>s+a.points_balance,0);
 app.innerHTML='<div class="eyebrow">لوحة التاجر · '+esc(m.slug)+'</div>'+hero('مركز إدارة الولاء',esc(m.name),'تحكم في برامجك ومكافآتك، وراقب تفاعل العملاء من لوحة واحدة.','<span class="tag '+(m.status==='active'?'':'gold')+'">'+({pending:'بانتظار المراجعة',active:'متجر نشط',suspended:'موقوف',rejected:'مرفوض'}[m.status]||m.status)+'</span>')+top('نظرة عامة','أداء متجرك في لمحة واحدة.')+'<div class="stat-grid"><div class="stat"><span>برامج الولاء</span><strong>'+programs.length+'</strong></div><div class="stat"><span>حسابات العملاء</span><strong>'+customers+'</strong></div><div class="stat"><span>النقاط المتداولة</span><strong>'+money(points)+'</strong></div><div class="stat"><span>حالة المتجر</span><strong style="font:600 14px IBM Plex Sans Arabic">'+(m.status==='active'?'نشط':'قيد المراجعة')+'</strong></div></div>'+top('برامج الولاء','أطلق برنامجاً أو طوّر قواعد برنامج قائم.')+'<div class="grid">'+(programs.length?programs.map(p=>'<article class="panel"><div class="panel-head"><span class="tag '+(p.state==='active'?'':'gray')+'">'+({active:'نشط',draft:'مسودة',paused:'متوقف',archived:'مؤرشف'}[p.state]||p.state)+'</span><span class="muted">v'+p.version+'</span></div><h3>'+esc(p.name)+'</h3><p class="muted">'+(p.kind==='points'?'برنامج نقاط':'برنامج أختام')+'</p></article>').join(''):'<div class="empty">لم تنشئ برنامجاً بعد.</div>')+'</div>'+top('إضافة مكافأة','اربط المكافأة ببرنامج ولاء محدد.')+'<div class="panel"><form id="rewardCreate"><div class="form-grid"><div class="field"><label>البرنامج</label><select name="program_id" required>'+programs.map(p=>'<option value="'+p.id+'">'+esc(p.name)+'</option>').join('')+'</select></div><div class="field"><label>اسم المكافأة</label><input name="title" required placeholder="مثال: قهوة مجانية"></div><div class="field"><label>تكلفة النقاط أو الأختام</label><input name="cost" type="number" min="1" step="1" required></div><div class="field"><label>وصف المكافأة</label><input name="description" placeholder="تفاصيل وشروط الاستبدال"></div></div><button class="btn btn-gold">حفظ المكافأة</button></form></div>+top('إنشاء برنامج جديد','ابدأ بإعداد نوع الولاء وقواعده الأساسية.')+'<div class="panel"><form id="programCreate"><div class="form-grid"><div class="field"><label>اسم البرنامج</label><input name="name" required placeholder="مثال: نقاط النخبة"></div><div class="field"><label>نوع البرنامج</label><select name="kind"><option value="points">نقاط</option><option value="stamps">أختام</option></select></div><div class="field"><label>نقاط لكل وحدة من العملة</label><input name="rate" type="number" min=".01" step=".01" value="1"></div><div class="field"><label>عدد الأختام للمكافأة</label><input name="goal" type="number" min="2" max="100" value="10"></div></div><button class="btn btn-gold">إنشاء البرنامج</button></form></div>';
}
function renderStaff(){
 if(!state.user){app.innerHTML=hero('بوابة الموظف','عمليات سريعة. دقة لا تقبل الخطأ.','أدخل رمز العميل، تحقق من صلاحيته، ونفّذ الاكتساب أو الاستبدال من خلال إجراءات خادمية آمنة.','<button class="btn btn-gold" data-login>دخول الموظف</button>');return}
 app.innerHTML='<div class="eyebrow">مساحة الموظف · العمليات الموثوقة</div>'+hero('نقطة خدمة الولاء','كل عملية موثقة. كل رصيد محمي.','لا تُعدّل الأرصدة يدوياً. استخدم الرموز المؤقتة لتأكيد عمليات الاكتساب والاستبدال.','<span class="tag gold">تحقق خادمي</span>')+top('تأكيد اكتساب النقاط أو الأختام','امسح رمز العميل وأدخل قيمة الفاتورة. الخادم يحسب الاستحقاق.')+'<div class="panel"><form id="earnConfirm"><div class="form-grid"><div class="field"><label>رمز العميل</label><input name="code" required minlength="12" maxlength="12" placeholder="12 حرفاً/رقماً" autocomplete="off"></div><div class="field"><label>قيمة المشتريات</label><input name="amount" type="number" min=".01" step=".01" required placeholder="0.00"></div></div><button class="btn btn-gold">تأكيد عملية الاكتساب</button></form></div>'+top('تأكيد استبدال مكافأة','تحقق من رمز الاستبدال وسلّم المكافأة بعد نجاح العملية.')+'<div class="panel"><form id="redeemConfirm"><div class="field"><label>رمز الاستبدال</label><input name="code" required minlength="12" maxlength="12" placeholder="12 حرفاً/رقماً" autocomplete="off"></div><button class="btn btn-outline">تأكيد الاستبدال</button></form></div>';
}
async function refresh(){
 if(!sb){app.innerHTML='<div class="empty">إعداد الاتصال غير مكتمل.</div>';return}
 const {data:{session}}=await sb.auth.getSession();state.user=session?.user||null;
 if(!state.user){render();return}
 try{if(state.view==='customer')await customerData();if(state.view==='merchant')await merchantData();render()}catch(e){console.error(e);app.innerHTML='<div class="empty"><b>تعذر تحميل البيانات</b>'+esc(e.message||'خطأ غير معروف')+'<br><button class="btn btn-soft" data-refresh>إعادة المحاولة</button></div>'}
}
async function action(fn){const x=await fn();if(x?.error)throw x.error;return x?.data??x}
document.addEventListener('click',async e=>{
 const v=e.target.closest('[data-view]');if(v){state.view=v.dataset.view;await refresh();return}
 if(e.target.closest('[data-login]')||e.target.id==='authButton'){dialog.showModal();return}
 if(e.target.closest('[data-close]')){dialog.close();return}
 if(e.target.closest('[data-refresh]')){await refresh();return}
 const j=e.target.closest('[data-join]');if(j){try{await action(()=>sb.rpc('join_loyalty_program',{p_program_id:j.dataset.join}));notify('تم الانضمام إلى البرنامج بنجاح');await refresh()}catch(err){notify(err.message)}return}
 const redeem=e.target.closest('[data-redeem]');if(redeem){try{if(!redeem.dataset.account)throw new Error('انضم إلى البرنامج أولاً');const r=await action(()=>sb.rpc('create_redeem_code',{p_account_id:redeem.dataset.account,p_reward_id:redeem.dataset.redeem}));if(!r.ok)throw new Error(r.error);app.insertAdjacentHTML('afterbegin','<div class="code-box" style="margin-bottom:18px"><span class="tag gold">رمز استبدال مؤقت</span><strong>'+esc(r.code)+'</strong><small>صالح لمدة '+r.expires_in+' ثانية. اعرضه على موظف المتجر.</small></div>');notify('تم إصدار رمز الاستبدال')}catch(err){notify(err.message)}return}\n const earn=e.target.closest('[data-earn]');if(earn){try{const r=await action(()=>sb.rpc('create_customer_checkin_code',{p_program_id:earn.dataset.earn}));if(!r.ok)throw new Error(r.error);app.insertAdjacentHTML('afterbegin','<div class="code-box" style="margin-bottom:18px"><span class="tag gold">رمز اكتساب مؤقت</span><strong>'+esc(r.code)+'</strong><small>صالح لمدة '+r.expires_in+' ثانية. اعرضه على موظف المتجر.</small></div>');notify('تم إصدار رمز مؤقت')}catch(err){notify(err.message)}}
});
document.addEventListener('submit',async e=>{
 const form=e.target;if(!form.matches('#authForm,#merchantCreate,#programCreate,#earnConfirm,#redeemConfirm'))return;e.preventDefault();
 try{
  if(form.id==='authForm'){
   $('#authError').textContent='';const phone=$('#phone').value.trim(),otp=$('#otp').value.trim(),btn=$('#authSubmit');btn.disabled=true;
   try{if(!state.otpSent){const {error}=await sb.auth.signInWithOtp({phone});if(error)throw error;state.otpSent=true;$('#otpWrap').hidden=false;btn.textContent='تحقق من الرمز';notify('أرسلنا رمز التحقق إلى هاتفك')}else{const {error}=await sb.auth.verifyOtp({phone,token:otp,type:'sms'});if(error)throw error;dialog.close();state.otpSent=false;await refresh();notify('تم تسجيل الدخول بنجاح')}}catch(err){$('#authError').textContent=err.message||'تعذر تسجيل الدخول'}finally{btn.disabled=false}return;
  }
  if(!state.user)throw new Error('سجّل الدخول أولاً');
  const f=new FormData(form);
  if(form.id==='merchantCreate'){
   const name=String(f.get('name')).trim(),slug='merchant-'+crypto.randomUUID().slice(0,8);
   await action(()=>sb.from('merchants').insert({owner_user_id:state.user.id,name,slug,category:f.get('category'),city:f.get('city'),description:f.get('description')}));
   notify('تم إنشاء ملف المتجر وهو بانتظار المراجعة');await refresh();return;
  }
  if(form.id==='rewardCreate'){\n   const pid=f.get('program_id'),program=state.merchant.loyalty_programs.find(p=>p.id===pid),cost=Number(f.get('cost'));\n   await action(()=>sb.from('rewards').insert({merchant_id:state.merchant.id,program_id:pid,title:f.get('title'),description:f.get('description'),points_cost:program?.kind==='points'?cost:null,stamps_cost:program?.kind==='stamps'?cost:null,is_active:true}));\n   notify('تم حفظ المكافأة');await refresh();return;\n  }\n  if(form.id==='programCreate'){
   await action(()=>sb.from('loyalty_programs').insert({merchant_id:state.merchant.id,name:f.get('name'),kind:f.get('kind'),points_per_currency:Number(f.get('rate')),stamp_goal:Number(f.get('goal')),state:'draft'}));
   notify('تم إنشاء البرنامج كمسودة');await refresh();return;
  }
  if(form.id==='earnConfirm'){
   const r=await action(()=>sb.rpc('confirm_earn_code',{p_code:String(f.get('code')).toUpperCase(),p_purchase_amount:Number(f.get('amount'))}));
   if(!r.ok)throw new Error(r.error);notify('نجحت العملية · أضيف '+money(r.points_added)+' نقطة و'+money(r.stamps_added)+' ختم');form.reset();return;
  }
  if(form.id==='redeemConfirm'){
   const r=await action(()=>sb.rpc('confirm_redeem_code',{p_code:String(f.get('code')).toUpperCase()}));
   if(!r.ok)throw new Error(r.error);notify('تم الاستبدال بنجاح · '+r.reward);form.reset();
  }
 }catch(err){notify(err.message||'حدث خطأ غير متوقع')}
});
$('#authButton').addEventListener('click',()=>dialog.showModal());
$('#profileButton').addEventListener('click',async()=>{if(sb)await sb.auth.signOut();state.user=null;state.accounts=[];state.merchant=null;render();notify('تم تسجيل الخروج')});
if(sb)sb.auth.onAuthStateChange((_event,session)=>{state.user=session?.user||null;refresh()});
window.addEventListener('online',()=>$('#connection').innerHTML='<i></i> متصل');
window.addEventListener('offline',()=>$('#connection').innerHTML='<i style="background:#d9a93e"></i> دون اتصال');
refresh();
