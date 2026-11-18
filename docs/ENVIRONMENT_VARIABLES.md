# متغيرات البيئة
| المتغير | أين | سري؟ |
|---|---|---|
| SUPABASE_URL | التطبيق والخادم | لا |
| SUPABASE_PUBLISHABLE_KEY | التطبيق | لا (مصمم للنشر مع RLS) |
| SUPABASE_SERVICE_ROLE_KEY | أسرار Edge Functions فقط | **نعم، لا يدخل التطبيق ولا المستودع** |
| TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN | إعدادات مزوّد المصادقة أو أسرار الخادم | **نعم** |
لا قيم فعلية في هذا الملف.
