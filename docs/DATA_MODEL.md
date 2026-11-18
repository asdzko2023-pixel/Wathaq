# نموذج البيانات (مطبّق في Postgres)
| الجدول | الغرض | كتابة العميل |
|---|---|---|
| profiles | الملف الشخصي (الاسم، اللغة، طلب الحذف) | اسمه ولغته فقط |
| platform_admins | مديرو المنصة | لا |
| platform_settings | الفترة التجريبية، السماح، قنوات الرموز | مدير فقط |
| plans | الباقات (غير مفعّلة حتى تُنفَّذ مزاياها) | مدير فقط |
| tiers | مستويات العميل وحدودها | مدير فقط |
| merchants | المتاجر، الحالة pending/approved/suspended، `is_test` | المالك: بيانات الملف دون الحالة |
| merchant_staff | الموظفون وصلاحياتهم | المالك فقط |
| subscriptions / subscription_events | الاشتراك وسجله (السجل لا يتعدل) | مدير فقط |
| programs | البرامج (نقاط/أختام) مع `version` | المالك |
| rewards | المكافآت | المالك |
| cards | بطاقة لكل عميل وبرنامج، تحمل الأرصدة | لا (قراءة فقط) |
| transactions | سجل العمليات، لا يتعدل ولا يُحذف، `idempotency_key` فريد | لا |
| reward_tokens | رموز الاستحقاق والاستبدال (مجزّأة) | لا وصول إطلاقًا |
| favorites | المفضلة | صاحبها |
| audit_logs | سجل التدقيق، لا يتعدل | لا (مدير يقرأ) |
## قرارات
- تعديل قواعد البرنامج يرفع `version` ويُسجَّل، وكل عملية تحفظ نسخة القاعدة التي طُبّقت.
- الفهارس مبدئية على المالك والحالة والعميل والمتجر، وتُراجع بعد قياس الاستعلامات.
- سياسات الاحتفاظ وحذف الحساب: لم تُضبط بعد (قرار مفتوح).
## لم يُنفَّذ بعد
المحلات والمواقع (MerchantLocations)، القسائم الورقية (MerchantCoupons)، الإشعارات، بلاغات الدعم.

## تحديث المرحلة 3
- `reward_tokens` أُضيفت أعمدة: `amount` (كمية الاكتساب)، `reference`، `card_id`، `reward_id`، `used_by`. تظل بلا أي سياسة وصول للعملاء.
- `merchant_staff.permissions` مقيّدة بقيد: `issue_earn` و`confirm_redeem` فقط.
- إعدادات جديدة في `platform_settings`: `earn_code_ttl_seconds` (120) و`redeem_code_ttl_seconds` (300).
- مفاتيح الفرادة في `transactions.idempotency_key`: `earn:<token_id>` و`redeem:<token_id>`.
- قواعد البرنامج الاختيارية في `programs.rules`: `per_code` (الكمية الافتراضية) و`max_per_code` (السقف).
