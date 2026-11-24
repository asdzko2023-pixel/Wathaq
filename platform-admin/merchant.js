(() => {
  const root = document.getElementById('merchant-app');
  const cfg = window.WATHAQ_CONFIG;
  const createClient = window.supabase?.createClient;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const fmt = value => Number(value ?? 0).toLocaleString('en-US');
  const date = value => value ? new Intl.DateTimeFormat('ar-YE',{dateStyle:'medium'}).format(new Date(value)) : '—';
  const money = value => value === null || value === undefined ? '—' : '$' + Number(value).toFixed(0);
  const statusNames = {active:'نشط',pending:'بانتظار المراجعة',suspended:'موقوف',rejected:'مرفوض'};
  const subscriptionNames = {active:'نشط',paused:'مجمّد',expired:'منتهي',cancelled:'ملغي',unassigned:'لم تُعيّن خطة'};
  const featureNames = {
    points_and_stamps:'النقاط والأختام',rewards_catalogue:'إدارة المكافآت',
    secure_qr_batches:'باركودات آمنة',basic_platform_reports:'التقارير الأساسية',
    campaigns:'الحملات الترويجية',program_branding:'هوية برامج الولاء',csv_export:'تصدير CSV',
    advanced_analytics:'التحليلات المتقدمة',customer_segments:'شرائح العملاء',
    multi_branch_reports:'تقارير الفروع',api_access:'تكامل API',custom_roles:'صلاحيات مخصصة',
    multi_branch_management:'إدارة فروع متعددة',priority_support:'دعم بأولوية',advanced_exports:'تصدير متقدم'
  };
  let sb = null;
  let currentUser = null;

  function toast(message, isError=false) {
    root.querySelector('.merchant-toast')?.remove();
    const node = document.createElement('div');
    node.className = 'merchant-toast' + (isError ? ' error' : '');
    node.textContent = message;
    root.append(node);
    window.setTimeout(() => node.remove(), 4200);
  }

  function loading(message='جارٍ تحميل بيانات متجرك…') {
    root.innerHTML = '<main class="center-state"><span class="brand-mark">و</span><p>' + esc(message) + '</p></main>';
  }

  function renderLogin(message='سجّل الدخول بحساب مالك المتجر المعتمد في وثاق.') {
    root.innerHTML =
      '<main class="merchant-login-card">' +
      '<div class="merchant-brand"><span class="brand-mark">و</span><div><strong>وِثاق</strong><small>بوابة مالك المتجر</small></div></div>' +
      '<h1>مرحباً بك في وثاق</h1><p>' + esc(message) + '</p>' +
      '<form id="merchant-login-form">' +
      '<label>البريد الإلكتروني<input class="search-input" id="merchant-email" type="email" dir="ltr" autocomplete="username" required maxlength="254"></label>' +
      '<label>كلمة المرور<input class="search-input" id="merchant-password" type="password" autocomplete="current-password" required></label>' +
      '<button class="primary-btn" type="submit">تسجيل الدخول</button></form>' +
      '<div class="merchant-login-actions"><button class="ghost-btn" id="merchant-google">المتابعة باستخدام Google</button><button class="ghost-btn" id="merchant-back">العودة إلى وثاق</button></div>' +
      '<p class="small">يجب أن يكون الحساب مرتبطاً بملكية متجر في قاعدة بيانات وثاق. تسجيل الدخول وحده لا يمنح صلاحية الوصول إلى بيانات متجر.</p>' +
      '</main>';

    root.querySelector('#merchant-login-form').addEventListener('submit', async event => {
      event.preventDefault();
      const button = event.submitter;
      button.disabled = true;
      const email = root.querySelector('#merchant-email').value.trim().toLowerCase();
      const password = root.querySelector('#merchant-password').value;
      const {error} = await sb.auth.signInWithPassword({email,password});
      if (error) {
        toast('تعذر تسجيل الدخول: ' + error.message, true);
        button.disabled = false;
        return;
      }
      await boot();
    });

    root.querySelector('#merchant-google').addEventListener('click', async event => {
      event.currentTarget.disabled = true;
      const redirectTo = window.location.origin + '/';
      const {error} = await sb.auth.signInWithOAuth({provider:'google',options:{redirectTo}});
      if (error) {
        toast('تعذر بدء تسجيل الدخول عبر Google: ' + error.message, true);
        event.currentTarget.disabled = false;
      }
    });

    root.querySelector('#merchant-back').addEventListener('click', () => {
      window.location.href = './';
    });
  }

  function featureTags(keys, planned=false) {
    const items = Array.isArray(keys) ? keys : [];
    if (!items.length) return '<span class="small muted">—</span>';
    return items.map(key => '<span>' + esc(featureNames[key] || key) + '</span>').join('');
  }

  function renderStoreCard(store) {
    const features = Array.isArray(store.live_features) ? store.live_features : [];
    const planned = Array.isArray(store.planned_features) ? store.planned_features : [];
    const now = Date.now();
    const validSubscription = store.subscription_status === 'active' &&
      (!store.starts_at || new Date(store.starts_at).getTime() <= now) &&
      !!store.ends_at && new Date(store.ends_at).getTime() > now;
    const exportAllowed = store.merchant_status === 'active' && validSubscription && features.includes('csv_export');
    const planActive = store.plan_key && validSubscription;
    const planLine = store.plan_name
      ? '<div><b>' + esc(store.plan_name) + '</b><div class="small muted">' + esc(store.plan_key) + '</div></div>'
      : '<div><b>لا توجد باقة معيّنة</b><div class="small muted">تواصل مع إدارة وثاق لتعيين خطة</div></div>';
    const planPrice = planActive ? '<strong class="merchant-plan-price">' + money(store.price_usd) + '<small> / شهر</small></strong>' : '';
    const status = subscriptionNames[store.subscription_status] || 'لم تُعيّن خطة';
    const billing = store.billing_status === 'manual_paid' ? 'مدفوع يدوياً' :
      store.billing_status === 'complimentary' ? 'مجاني / ترويجي' :
      store.billing_status === 'admin_assigned' ? 'تعيين إداري · الدفع غير مؤكد' : '—';

    return '<article class="merchant-store-card">' +
      '<div class="merchant-store-head">' +
      '<div><h2>' + esc(store.merchant_name) + '</h2><div class="small muted">' + esc(store.merchant_slug) + '</div></div>' +
      planPrice +
      '</div>' +
      '<div class="merchant-subscription-row">' + planLine +
      '<div><span class="status ' + (store.merchant_status === 'active' ? 'active' : 'pending') + '">' + esc(statusNames[store.merchant_status] || store.merchant_status) + '</span>' +
      '<div class="small muted">' + esc(status) + ' · ' + esc(billing) + '</div></div></div>' +
      '<div class="merchant-limits">' +
      '<span>الموظفون: ' + fmt(store.staff_limit) + '</span>' +
      '<span>البرامج النشطة: ' + fmt(store.active_program_limit) + '</span>' +
      '<span>QR شهرياً: ' + fmt(store.monthly_qr_limit) + '</span>' +
      '</div>' +
      '<div class="merchant-section-label">ملخص نشاط الولاء · آخر 30 يوماً للنقاط</div>' +
      '<div class="merchant-stats">' +
      '<div class="merchant-stat"><span>برامج الولاء</span><strong>' + fmt(store.loyalty_programs_total) + '</strong></div>' +
      '<div class="merchant-stat"><span>البرامج النشطة</span><strong>' + fmt(store.active_programs_total) + '</strong></div>' +
      '<div class="merchant-stat"><span>حسابات الولاء</span><strong>' + fmt(store.loyalty_accounts_total) + '</strong></div>' +
      '<div class="merchant-stat"><span>المكافآت النشطة</span><strong>' + fmt(store.active_rewards_total) + '</strong></div>' +
      '<div class="merchant-stat"><span>النقاط المكتسبة · 30 يوماً</span><strong>' + fmt(store.points_earned_30d) + '</strong></div>' +
      '<div class="merchant-stat"><span>النقاط المستبدلة · 30 يوماً</span><strong>' + fmt(store.points_redeemed_30d) + '</strong></div>' +
      '</div>' +
      '<div class="merchant-section-label">المزايا المتاحة في خطتك</div><div class="merchant-features">' + featureTags(features) + '</div>' +
      (planned.length ? '<div class="merchant-section-label">مزايا قيد التطوير وليست مفعّلة</div><div class="merchant-features planned">' + featureTags(planned,true) + '</div>' : '') +
      '<div class="merchant-section-label">تاريخ نهاية الاشتراك</div><div class="small muted">' + date(store.ends_at) + '</div>' +
      (exportAllowed
        ? '<div class="merchant-csv-action"><p><b>تصدير بيانات الولاء CSV</b><br>يشمل معرّفاً مرجعياً للعميل، البرنامج، الأرصدة، وتواريخ النشاط. لا يتضمن أسماء العملاء أو بريدهم أو أرقام هواتفهم.</p><button class="primary-btn" data-export="' + esc(store.merchant_id) + '">تصدير ملف CSV</button></div>'
        : (features.includes('csv_export')
          ? '<div class="merchant-note">ميزة التصدير غير متاحة حالياً لأن حالة المتجر أو الاشتراك لا تسمح بها.</div>'
          : '<div class="merchant-note">تصدير CSV متاح ضمن باقة Growth بقيمة 19 دولاراً شهرياً بعد تعيينها وتفعيل الاشتراك من إدارة المنصة.</div>')) +
      '</article>';
  }

  function renderWorkspace(stores) {
    root.innerHTML =
      '<main class="merchant-shell">' +
      '<header class="merchant-topbar"><div class="merchant-brand"><span class="brand-mark">و</span><div><strong>وِثاق</strong><small>بوابة مالك المتجر</small></div></div>' +
      '<div class="merchant-user"><span dir="ltr">' + esc(currentUser?.email || '') + '</span><button id="merchant-signout" class="ghost-btn">تسجيل الخروج</button></div></header>' +
      '<h1 class="merchant-page-title">لوحة متجرك</h1><p class="merchant-subtitle">هذه البيانات مرتبطة بملكية المتجر المسجلة في قاعدة بيانات وثاق، وليست بيانات تجريبية.</p>' +
      '<div class="merchant-store-grid">' + stores.map(renderStoreCard).join('') + '</div>' +
      '<div class="merchant-note">الأرصدة وعمليات الولاء تُدار من قاعدة البيانات. هذه اللوحة تعرض ملخصاً فقط؛ لا تسمح بتعديل رصيد النقاط أو سجل الحركات. تُسجّل عمليات تصدير CSV في سجل التدقيق.</div>' +
      '</main>';

    root.querySelector('#merchant-signout').addEventListener('click', async () => {
      await sb.auth.signOut();
      renderLogin('تم تسجيل الخروج.');
    });
    root.querySelectorAll('[data-export]').forEach(button => {
      button.addEventListener('click', () => exportCsv(button.dataset.export, button));
    });
  }

  function csvCell(value) {
    let text = value === null || value === undefined ? '' : String(value);
    if (/^[\t\r\n ]*[=+@-]/.test(text)) text = "'" + text;
    return '"' + text.replace(/"/g, '""') + '"';
  }

  function makeCsv(rows) {
    const headers = [
      'معرّف سجل الولاء','مرجع العميل (معرّف غير اسمي)','اسم برنامج الولاء','نوع البرنامج',
      'رصيد النقاط','رصيد الأختام','إجمالي النقاط مدى الحياة','إجمالي الأختام مدى الحياة',
      'تاريخ الانضمام','آخر نشاط'
    ];
    const lines = [headers.map(csvCell).join(',')];
    rows.forEach(row => {
      lines.push([
        row.account_id,row.customer_reference,row.program_name,row.program_kind,
        row.points_balance,row.stamps_balance,row.lifetime_points,row.lifetime_stamps,
        row.joined_at,row.last_activity_at
      ].map(csvCell).join(','));
    });
    return '\uFEFF' + lines.join('\r\n');
  }

  async function exportCsv(merchantId, button) {
    const originalText = button.textContent;
    button.disabled = true;
    const pageSize = 1000;
    const maxPages = 50;
    const rows = [];
    let afterJoinedAt = null;
    let afterAccountId = null;
    let snapshotAt = null;
    try {
      for (let page = 0; page < maxPages; page++) {
        button.textContent = 'جارٍ التصدير… ' + fmt(rows.length);
        const {data,error} = await sb.rpc('merchant_export_loyalty_accounts',{
          p_merchant_id:merchantId,
          p_after_joined_at:afterJoinedAt,
          p_after_account_id:afterAccountId,
          p_snapshot_at:snapshotAt,
          p_limit:pageSize
        });
        if (error) throw error;
        const batch = data || [];
        if (!batch.length) break;
        if (!snapshotAt) snapshotAt = batch[0].snapshot_at;
        rows.push(...batch);
        const last = batch[batch.length - 1];
        afterJoinedAt = last.joined_at;
        afterAccountId = last.account_id;
        if (batch.length < pageSize) break;
        if (page === maxPages - 1) {
          const {data:extra,error:extraError} = await sb.rpc('merchant_export_loyalty_accounts',{
            p_merchant_id:merchantId,
            p_after_joined_at:afterJoinedAt,
            p_after_account_id:afterAccountId,
            p_snapshot_at:snapshotAt,
            p_limit:1
          });
          if (extraError) throw extraError;
          if ((extra || []).length) {
            throw new Error('يتجاوز حجم التصدير الآمن 50,000 حساب. قسّم العملية أو تواصل مع إدارة وثاق.');
          }
        }
      }

      const csv = makeCsv(rows);
      const blob = new Blob([csv],{type:'text/csv;charset=utf-8'});
      const objectUrl = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = objectUrl;
      link.download = 'wathaq_loyalty_' + merchantId + '_' + new Date().toISOString().slice(0,10) + '.csv';
      document.body.append(link);
      link.click();
      link.remove();
      window.setTimeout(() => URL.revokeObjectURL(objectUrl),1000);
      toast('تم تجهيز ملف CSV بعدد ' + fmt(rows.length) + ' سجل. سُجّلت صفحات التصدير في سجل التدقيق.');
    } catch (error) {
      toast('تعذر تصدير البيانات: ' + (error?.message || 'خطأ غير معروف'),true);
    } finally {
      button.disabled = false;
      button.textContent = originalText;
    }
  }

  async function boot() {
    if (!createClient || !cfg?.url || !cfg?.key) {
      root.innerHTML = '<main class="center-state"><section class="denied-card"><h1>إعداد الاتصال غير مكتمل</h1><p>تعذر تحميل إعداد Supabase العام.</p></section></main>';
      return;
    }
    sb = createClient(cfg.url,cfg.key,{auth:{persistSession:true,autoRefreshToken:true,flowType:'pkce'}});
    const {data,error} = await sb.auth.getSession();
    if (error) { renderLogin('تعذر استعادة جلسة الدخول: ' + error.message); return; }
    currentUser = data.session?.user;
    if (!currentUser) { renderLogin(); return; }
    loading();
    const {data:stores,error:workspaceError} = await sb.rpc('merchant_get_my_workspace');
    if (workspaceError) {
      root.innerHTML = '<main class="center-state"><section class="denied-card"><h1>تعذر تحميل بيانات المتجر</h1><p>' + esc(workspaceError.message) + '</p><button class="ghost-btn" id="merchant-signout">تسجيل الخروج</button></section></main>';
      root.querySelector('#merchant-signout').addEventListener('click',() => sb.auth.signOut());
      return;
    }
    if (!Array.isArray(stores) || !stores.length) {
      root.innerHTML = '<main class="center-state"><section class="denied-card"><h1>لا توجد ملكية متجر لهذا الحساب</h1><p>لا يوجد متجر مرتبط بملكية هذا الحساب في وثاق. لا يمنح تسجيل الدخول وحده صلاحية الوصول إلى المتاجر.</p><button class="ghost-btn" id="merchant-signout">تسجيل الخروج</button></section></main>';
      root.querySelector('#merchant-signout').addEventListener('click',() => sb.auth.signOut());
      return;
    }
    renderWorkspace(stores);
  }

  boot().catch(error => {
    root.innerHTML = '<main class="center-state"><section class="denied-card"><h1>تعذر فتح بوابة التاجر</h1><p>' + esc(error?.message || 'حدث خطأ غير متوقع') + '</p></section></main>';
  });
})();
