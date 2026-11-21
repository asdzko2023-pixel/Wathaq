import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/wathaq_components.dart';

class CheckinCodeSheet extends StatefulWidget {
  const CheckinCodeSheet({super.key});

  @override
  State<CheckinCodeSheet> createState() => _CheckinCodeSheetState();
}

class _CheckinCodeSheetState extends State<CheckinCodeSheet> {
  late final Future<List<_ProgramOption>> _programs = _loadPrograms();
  bool _creating = false;

  Future<List<_ProgramOption>> _loadPrograms() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw AuthException('يلزم تسجيل الدخول.');
    final accounts = await client.from('loyalty_accounts')
        .select('program_id')
        .eq('customer_id', user.id);
    if (accounts.isEmpty) return const [];
    final ids = accounts.map((row) => row['program_id'] as String).toList();
    final programs = await client.from('loyalty_programs')
        .select('id,name,merchant_id')
        .eq('state', 'active')
        .inFilter('id', ids);
    if (programs.isEmpty) return const [];
    final merchantIds = programs.map((row) => row['merchant_id'] as String).toSet().toList();
    final merchants = await client.from('merchants').select('id,name').inFilter('id', merchantIds);
    final names = {for (final row in merchants) row['id'] as String: row['name'] as String};
    return programs.map((row) => _ProgramOption(
      id: row['id'] as String,
      name: row['name'] as String,
      merchant: names[row['merchant_id']] ?? 'متجر مشارك',
    )).toList();
  }

  Future<void> _createCode(_ProgramOption program) async {
    setState(() => _creating = true);
    try {
      final response = await Supabase.instance.client.rpc(
        'create_customer_checkin_code',
        params: {'p_program_id': program.id},
      );
      final payload = Map<String, dynamic>.from(response as Map);
      if (payload['ok'] != true) {
        final reason = switch (payload['error']) {
          'account_not_found' => 'لم يتم العثور على عضويتك في هذا البرنامج.',
          'merchant_unavailable' => 'المتجر غير متاح حالياً.',
          _ => 'تعذر إنشاء رمز تسجيل الزيارة.',
        };
        throw Exception(reason);
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _CheckinCodeDialog(
          code: payload['code'] as String,
          expiresIn: (payload['expires_in'] as num?)?.toInt() ?? 120,
          merchant: program.merchant,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('اعرض رمزك للمتجر', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('اختر برنامج الولاء لإنشاء رمز مؤقت وآمن لتسجيل زيارتك وكسب النقاط.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.wt.textMuted)),
        const SizedBox(height: 16),
        FutureBuilder<List<_ProgramOption>>(
          future: _programs,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return const Padding(padding: EdgeInsets.all(16), child: Text('تعذر تحميل برامجك. تحقق من الاتصال وحاول مجدداً.'));
            }
            final programs = snapshot.data ?? const [];
            if (programs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا تملك عضوية في برنامج نشط بعد. افتح صفحة المتاجر وانضم إلى أحد برامج الولاء أولاً.', textAlign: TextAlign.center),
              );
            }
            return Column(
              children: programs.map((program) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: _creating ? null : () => _createCode(program),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  child: Row(children: [
                    const Icon(Icons.storefront_rounded),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(program.name),
                      Text(program.merchant, style: Theme.of(context).textTheme.bodySmall),
                    ])),
                    if (_creating) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    else const Icon(Icons.qr_code_2_rounded),
                  ]),
                ),
              )).toList(),
            );
          },
        ),
      ],
    ),
  );
}

class _ProgramOption {
  const _ProgramOption({required this.id, required this.name, required this.merchant});
  final String id, name, merchant;
}

class _CheckinCodeDialog extends StatelessWidget {
  const _CheckinCodeDialog({required this.code, required this.expiresIn, required this.merchant});
  final String code, merchant;
  final int expiresIn;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('رمز تسجيل الزيارة'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(merchant, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        QrImageView(data: code, size: 220, backgroundColor: Colors.white),
        const SizedBox(height: 10),
        SelectableText(code, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text('هذا الرمز صالح لمدة $expiresIn ثانية فقط. اعرضه على موظف المتجر.', textAlign: TextAlign.center),
      ],
    ),
    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق'))],
  );
}
