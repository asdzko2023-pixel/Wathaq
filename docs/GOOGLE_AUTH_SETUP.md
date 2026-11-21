# إعداد تسجيل الدخول عبر Google — WATHAQ-CORE

التطبيق يستخدم Supabase Auth OAuth. زر Google ينشئ حسابًا جديدًا تلقائيًا عند أول موافقة، ويسجل دخول المستخدمين الحاليين في المرات التالية. لا يحتاج المستخدم إلى SMS OTP.

## إعداد Google Cloud
1. افتح Google Cloud Console وأنشئ/اختر مشروع WATHAQ.
2. أكمل Google Auth Platform branding وAudience حسب سياسة النشر.
3. أنشئ OAuth Client ID من النوع Web application.
4. أضف أصل موقع التطبيق إلى Authorized JavaScript origins.
5. أضف عنوان callback التالي إلى Authorized redirect URIs:
   `https://ncfromrlnlotrwkgjenk.supabase.co/auth/v1/callback`
6. احتفظ بـ Client ID وClient Secret؛ لا تضعهما في ملفات GitHub أو كود الواجهة.

## إعداد Supabase
1. افتح Authentication → Sign In / Providers → Google في مشروع WATHAQ-CORE.
2. فعّل Google والصق Client ID وClient Secret ثم احفظ.
3. من Authentication → URL Configuration، اضبط Site URL إلى عنوان الاستضافة الفعلي.
4. أضف عنوان الاستضافة الفعلي إلى Redirect URLs. أضف عنوان localhost فقط لبيئة التطوير عند الحاجة.
5. لا تضف wildcard واسعًا لقائمة Redirect URLs.

## تجربة الدخول
- افتح التطبيق واضغط «تسجيل الدخول» ثم «المتابعة باستخدام Google».
- وافق على حساب Google؛ سيعود المستخدم إلى عنوان التطبيق نفسه.
- أول دخول ينشئ مستخدم Auth تلقائيًا. لا يمنح هذا المستخدم دور Super Admin أو التاجر تلقائيًا.
- أضف أول Super Admin فقط بعد التأكد من هوية الحساب عبر إجراء التهيئة الموثق في PLATFORM_BOOTSTRAP.md.
- لا تشارك Client Secret أو رموز OAuth في المحادثات أو مستودع Git.

## حدود التنفيذ الحالي
زر OAuth والكود موجودان في الواجهة. لن يعمل تسجيل Google فعليًا حتى يتم إدخال Client ID وClient Secret وتفعيل المزود في لوحة Supabase، وإضافة Redirect URL الصحيحة.
