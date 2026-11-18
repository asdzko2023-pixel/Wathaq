# وِثاق | WATHAQ
منصة ولاء متعددة المتاجر، تجمع برامج النقاط والأختام والمكافآت في تجربة عربية راقية.

## اتجاه البناء الجديد
يعاد تأسيس المنتج على قاعدة مستقلة باسم **WATHAQ-CORE**. ملفات WATHAQ_SOURCE_v0.5.zip وWATHAQ_SOURCE_v0.6.zip مراجع لفهم السلوك والهوية فقط؛ لا يتم ربط النظام الجديد بقاعدة NOVEXA أو بقاعدة WATHAQ القديمة.

## المستودع
- web/: واجهة ويب عربية للعميل والتاجر والموظف والإدارة المركزية، مع تسجيل OTP ودعوات الموظفين.
- WATHAQ_SOURCE_v0.6.zip: الأرشيف المرجعي المحفوظ دون تعديل.
- .github/workflows/expand-source.yml: محاولة أتمتة توسيع المصدر المرجعي على فرع التطوير.

## قاعدة البيانات الجديدة
- Project: WATHAQ-CORE
- Project ref: ncfromrlnlotrwkgjenk
- Region: eu-central-1 (Frankfurt)
- الجداول الأساسية: profiles, merchants, merchant_members, loyalty_programs, rewards, loyalty_accounts, loyalty_ledger, loyalty_tokens, favorites, audit_events, platform_admins, platform_settings.
- كل جداول public مفعّل عليها RLS.
- الأرصدة ودفتر الحركات لا يملك العميل أو التاجر صلاحية تعديلها مباشرة.
- عمليات الاكتساب والاستبدال تنفذ عبر RPCs خادمية مع قفل السجلات ومفاتيح idempotency ورموز مؤقتة مجزّأة.
- تخزين صور المتاجر والمكافآت عبر Storage buckets مستقلة بسياسات رفع مرتبطة بعضوية التاجر.

## واجهة التطوير
افتح web/index.html عبر خادم static محلي. إعداد Supabase موجود في web/config.js ويحتوي على publishable key فقط.

## حالة التطوير
هذه مرحلة تأسيس أولى وليست إصدار إنتاج. ما زال مطلوباً استكمال إعداد مزود SMS لتسجيل الهاتف، تهيئة أول Super Admin، إدارة نشر البرامج والخطط، اختبارات تكامل مصادقة حقيقية، اختبارات تزامن وحمل، وتدقيق أمني مستقل. لا تُستخدم بيانات أو أرصدة تجريبية على أنها حقيقية.
