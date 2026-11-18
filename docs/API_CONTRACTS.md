# عقود واجهات الخادم (Supabase RPC)
كلها تُستدعى بـ `supabase.rpc(name, args)` من مستخدم مسجّل الدخول. **الفشل المتوقع يُرجَع ولا يُرمى**: `{"ok":false,"error":"<code>"}`، وتُرمى الاستثناءات لعدم تسجيل الدخول فقط. رسائل المستخدم تُشتق من الرمز في الواجهة، ولا تُعرض نصوص الخادم.

| الدالة | من يستدعيها | المدخلات | النجاح |
|---|---|---|---|
| `join_program(p_program_id)` | العميل | معرّف البرنامج | معرّف البطاقة (تكرار الاستدعاء يعيد نفس البطاقة) |
| `issue_earn_code(p_program_id, p_amount?, p_reference?)` | المالك أو موظف بصلاحية `issue_earn` | البرنامج، الكمية (اختياري وبسقف)، مرجع | `{ok, code, expires_at, amount}` |
| `claim_earn_code(p_code)` | العميل (هاتف موثّق) | الرمز | `{ok, replay, type, added, balance, merchant, card_id}` |
| `request_redeem(p_card_id, p_reward_id)` | العميل (هاتف موثّق) | البطاقة والمكافأة | `{ok, code, expires_at, reward, cost}` (لا يُخصم شيء) |
| `confirm_redeem(p_code)` | المالك أو موظف بصلاحية `confirm_redeem` | رمز العميل | `{ok, replay, reward, deducted, balance, customer_ref}` |

## رموز الأخطاء
`forbidden` · `rate_limited` · `invalid_amount` · `phone_not_verified` · `too_many_attempts` · `invalid_code` · `code_used` · `code_unavailable` · `code_expired` · `program_unavailable` · `not_joined` (لا يُستهلك الرمز؛ انضم ثم أعد المحاولة) · `not_found` · `reward_unavailable` · `insufficient_balance` · `wrong_store`

## قواعد
- الرمز `XXXX-XXXX` (32 حرفًا بلا ما يلتبس)، يُخزَّن مجزّأً فقط، ومدته من `platform_settings` (`earn_code_ttl_seconds` 120، `redeem_code_ttl_seconds` 300) بساعة الخادم.
- إعادة الطلب نفسه من المستخدم نفسه تعيد النتيجة الأصلية (`replay:true`) ولا تنفّذ عملية ثانية.
- طلب استبدال جديد لنفس البطاقة والمكافأة يلغي الرمز السابق.
- الصلاحيات المسموحة للموظف: `issue_earn` و`confirm_redeem` فقط (قيد في قاعدة البيانات).
- 8 محاولات فاشلة خلال 10 دقائق توقف المحاولات؛ 10 رموز اكتساب في الدقيقة كحد أقصى لكل موظف؛ 5 طلبات استبدال في الدقيقة لكل عميل.
