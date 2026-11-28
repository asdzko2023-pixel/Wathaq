# عقود API الحالية — WATHAQ-CORE

جميع الاستدعاءات من الواجهة تستخدم Supabase JS مع مستخدم مسجل الدخول. كل دوال RPC العامة محمية، وتتطلب هوية `auth.uid()`. لا تستخدم أسماء الدوال القديمة الموجودة في أرشيف v0.6.

## RPCs العامة

| الدالة | من يستدعيها | المدخلات | النتيجة |
|---|---|---|---|
| `join_loyalty_program` | العميل | `p_program_id: uuid` | UUID لحساب الولاء؛ الانضمام مكررًا لا ينشئ حسابًا ثانيًا |
| `create_customer_checkin_code` | العميل | `p_program_id: uuid` | `{ok, code, expires_in}`؛ رمز اكتساب مؤقت |
| `create_redeem_code` | العميل صاحب الحساب | `p_account_id: uuid, p_reward_id: uuid` | `{ok, code, expires_in}`؛ لا يخصم الرصيد عند الإصدار |
| `confirm_earn_code` | موظف/مالك بصلاحية الاكتساب | `p_code: text, p_purchase_amount: numeric` | `{ok, points_added, stamps_added, points_balance, stamps_balance}` |
| `confirm_redeem_code` | موظف/مالك بصلاحية الاستبدال | `p_code: text` | `{ok, reward, points_balance, stamps_balance}` |
| `create_merchant_invite` | مدير المتجر المخوّل | `p_merchant_id, p_phone_e164, p_permissions` | `{ok, invite_id, code, expires_in_hours}`؛ الدعوة مرتبطة برقم الهاتف |
| `accept_merchant_invite` | المستخدم صاحب رقم الهاتف المدعو | `p_code: text` | `{ok, merchant_id, permissions}` |
| `list_merchant_members` | مدير المتجر | `p_merchant_id: uuid` | `{ok, members}` |
| `set_merchant_member` | مدير المتجر | `p_merchant_id, p_user_id, p_permissions?, p_active?` | `{ok}` بعد التحقق من الصلاحية وعدم تعديل المالك |

## قواعد المعاملات
- الرمز العشوائي يُعرض مرة واحدة، ويُخزَّن digest فقط في `loyalty_tokens`.
- رموز الاكتساب والاستبدال أحادية الاستخدام ولها وقت انتهاء من ساعة الخادم.
- تأكيد الاكتساب/الاستبدال يتم داخل معاملة قاعدة بيانات، مع قفل السجلات ذات الصلة.
- دفتر الحركات append-only، ومفتاح idempotency يمنع تكرار العملية.
- خصم المكافأة من المخزون وخصم رصيد العميل يحدثان ذريًا عند تأكيد الاستبدال فقط.
- لا يملك العميل صلاحية تعديل الأرصدة أو إدخال/تعديل دفتر الحركات أو قراءة الرموز والدعوات مباشرة.

## أخطاء متوقعة
ترجع العمليات المحمية أخطاء منسقة مثل `{ok:false,error:"invalid_code"}` أو `not_authorized` أو `code_used` أو `code_expired` أو `insufficient_balance` أو `out_of_stock`. لا تعرض الواجهة نصوص SQL أو تفاصيل داخلية للمستخدم.

## حدود الأمان
- تسع دوال RPC في schema `public` متاحة للدور `authenticated` فقط؛ لا يوجد تنفيذ من `anon`.
- الدوال المساعدة في schema `private` ليست ضمن واجهة API العامة. خمس دوال فقط لها EXECUTE للدور authenticated لأنها مطلوبة داخل سياسات RLS ومسارات RPC؛ لا واحدة منها متاحة لـ anon.
- جميع دوال RPC العامة تستخدم `SECURITY DEFINER` مع `search_path = ''` وتتحقق من هوية المستخدم. راجع `docs/SECURITY_REVIEW.md` قبل تعديل أي دالة.
