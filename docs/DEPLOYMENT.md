# النشر والتشغيل — WATHAQ-CORE

## البيئة الحالية
- Supabase project: `WATHAQ-CORE`، المرجع `ncfromrlnlotrwkgjenk`، المنطقة `eu-central-1`.
- حالة المشروع في آخر تحقق: `ACTIVE_HEALTHY`.
- هذه قاعدة مستقلة ونظيفة للاختبار والتجهيز؛ لا تعتبر بيئة إنتاج مكتملة قبل إنهاء شروط `docs/RELEASE_READINESS.md`.
- لا تستخدم مشروع NOVEXA أو مشروع WATHAQ القديم لهذا التطبيق.

## بناء الواجهة
المصدر الفعلي في `web/`. يبني الأمر التالي نسخة الاستضافة في `public/`:

```bash
node app/build.mjs
node --check web/app.js
node --check public/app.js
```

يجب أن تطابق ملفات `public/` ملفات المصدر. GitHub Actions يتحقق من ذلك ويرفع artifact باسم `wathaq-core-public`.

## GitHub Pages
- سير العمل يبني من `web/` و`app/build.mjs` مباشرة.
- أرشيف `WATHAQ_SOURCE_v0.6.zip` مرجع تاريخي فقط؛ لا يفكّه مسار النشر ولا يبني منه.
- فحوصات CI تعمل على الفروع وطلبات الدمج.
- النشر الإنتاجي التلقائي معطل. لا يعمل deploy job إلا عند تشغيل workflow يدويًا على فرع `main` واختيار `deploy_production=true` بعد إغلاق كل بنود الجاهزية.
- يجب التأكد من إعداد GitHub Pages وHTTPS قبل اختبار تثبيت PWA.

## قاعدة البيانات
- المخطط الحالي مسجل في 15 هجرة على WATHAQ-CORE.
- `supabase/bootstrap/wathaq-core.sql` نسخة bootstrap مجمعة لمشروع Supabase جديد؛ لا تعِد تشغيل ملفات `reference/v0.6/` على القاعدة الحالية.
- لا تعدّل هجرة مطبقة؛ أضف تغييرًا جديدًا وحدث bootstrap واختبار العقد الأمني.
- لا تضع مفتاح `service_role` أو `sb_secret_` في الواجهة. `web/config.js` يحتوي على publishable key فقط.

## بوابات مطلوبة قبل الإنتاج
1. إعداد SMS provider وتأكيد OTP وإعادة الإرسال وحدود الإساءة وأرقام اليمن الحقيقية.
2. إنشاء أول Super Admin من حساب هاتف موثّق عبر `docs/PLATFORM_BOOTSTRAP.md`.
3. اختبار مسارات العميل والمالك والموظف على JWTs حقيقية.
4. اختبار التزامن والحمل والنسخ الاحتياطي والاستعادة.
5. مراجعة أمنية مستقلة وسياسة الخصوصية والشروط.
6. اختبار Android فعلي. النسخة الحالية PWA وليست APK أصليًا.
7. بعد اجتياز ما سبق فقط: تشغيل Pages يدويًا من `main` مع `deploy_production=true`.


## تسجيل الدخول عبر Google
راجع `docs/GOOGLE_AUTH_SETUP.md` لإعداد OAuth Client وتفعيل Google provider في WATHAQ-CORE. التطبيق يبدأ OAuth عبر Supabase Auth ويعود إلى عنوان الصفحة الحالي؛ يجب إدراج عنوان الاستضافة في Redirect URLs. لا توجد حاجة لمزود SMS لمسار تسجيل Google.
