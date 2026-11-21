import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/wathaq_components.dart';

final rewardsProvider = FutureProvider.autoDispose<List<CustomerReward>>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) throw AuthException('يلزم تسجيل الدخول.');
  final rows = await client.from('rewards')
      .select('id,title,description,points_cost,stamps_cost,program_id,merchant_id')
      .eq('is_active', true)
      .order('created_at', ascending: false);
  if (rows.isEmpty) return const [];

  final merchantIds = rows.map((r) => r['merchant_id'] as String).toSet().toList();
  final programIds = rows.map((r) => r['program_id'] as String).toSet().toList();
  final merchants = await client.from('merchants').select('id,name').inFilter('id', merchantIds);
  final programs = await client.from('loyalty_programs').select('id,name,kind').inFilter('id', programIds);
  final accounts = await client.from('loyalty_accounts')
      .select('id,program_id,points_balance,stamps_balance')
      .eq('customer_id', user.id);
  final merchantNames = {for (final m in merchants) m['id'] as String: m['name'] as String};
  final programById = {for (final p in programs) p['id'] as String: p};
  final accountByProgram = {for (final a in accounts) a['program_id'] as String: a};

  return rows.map((row) {
    final program = programById[row['program_id']] ?? const <String, dynamic>{};
    final account = accountByProgram[row['program_id']];
    return CustomerReward(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      merchantName: merchantNames[row['merchant_id']] ?? 'متجر مشارك',
      programId: row['program_id'] as String,
      accountId: account?['id'] as String?,
      pointsCost: (row['points_cost'] as num?)?.toInt(),
      stampsCost: (row['stamps_cost'] as num?)?.toInt(),
      balance: program['kind'] == 'stamps'
          ? (account?['stamps_balance'] as num?)?.toInt() ?? 0
          : (account?['points_balance'] as num?)?.toInt() ?? 0,
      kind: program['kind'] as String? ?? 'points',
    );
  }).toList();
});

class CustomerReward {
  const CustomerReward({
    required this.id, required this.title, required this.description,
    required this.merchantName, required this.programId, required this.accountId,
    required this.pointsCost, required this.stampsCost, required this.balance,
    required this.kind,
  });
  final String id, title, description, merchantName, programId, kind;
  final String? accountId;
  final int? pointsCost, stampsCost;
  final int balance;
}

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  Future<void> _redeem(BuildContext context, WidgetRef ref, CustomerReward reward) async {
    try {
      String? accountId = reward.accountId;
      if (accountId == null) {
        accountId = await Supabase.instance.client.rpc(
          'join_loyalty_program',
          params: {'p_program_id': reward.programId},
        ) as String?;
        ref.invalidate(rewardsProvider);
      }
      if (accountId == null) throw Exception('تعذر إنشاء حساب الولاء.');
      final response = await Supabase.instance.client.rpc(
        'create_redeem_code',
        params: {'p_account_id': accountId, 'p_reward_id': reward.id},
      );
      final payload = Map<String, dynamic>.from(response as Map);
      if (payload['ok'] != true) {
        final reason = switch (payload['error']) {
          'insufficient_balance' => 'رصيدك الحالي لا يكفي لاستبدال هذه المكافأة.',
          'reward_unavailable' => 'هذه المكافأة لم تعد متاحة.',
          'program_unavailable' => 'برنامج الولاء غير متاح حالياً.',
          'merchant_unavailable' => 'المتجر غير متاح حالياً.',
          _ => 'تعذر إصدار رمز الاستبدال.',
        };
        throw Exception(reason);
      }
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _RedeemCodeDialog(
          code: payload['code'] as String,
          expiresIn: (payload['expires_in'] as num?)?.toInt() ?? 300,
        ),
      );
      ref.invalidate(rewardsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('مكافآتي')),
      body: rewards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 12),
            const Text('تعذر تحميل المكافآت'),
            TextButton(onPressed: () => ref.invalidate(rewardsProvider), child: const Text('إعادة المحاولة')),
          ],
        )),
        data: (items) => items.isEmpty
            ? const Center(child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.card_giftcard_outlined, size: 48),
                  SizedBox(height: 12),
                  Text('لا توجد مكافآت متاحة حالياً'),
                  SizedBox(height: 6),
                  Text('ستظهر هنا مكافآت برامج الولاء النشطة.', textAlign: TextAlign.center),
                ]),
              ))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final reward = items[index];
                  final cost = reward.kind == 'stamps' ? reward.stampsCost : reward.pointsCost;
                  final unit = reward.kind == 'stamps' ? 'ختم' : 'نقطة';
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.wt.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.wt.outline),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: context.wt.gold.withValues(alpha: .18),
                          child: Icon(Icons.redeem_rounded, color: context.wt.primary, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reward.title, style: Theme.of(context).textTheme.titleMedium),
                            Text(reward.merchantName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.wt.textMuted)),
                            if (cost != null) Text('$cost $unit', style: TextStyle(color: context.wt.primary, fontWeight: FontWeight.w800)),
                          ],
                        )),
                        FilledButton(
                          onPressed: () => _redeem(context, ref, reward),
                          child: const Text('استبدل'),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _RedeemCodeDialog extends StatelessWidget {
  const _RedeemCodeDialog({required this.code, required this.expiresIn});
  final String code;
  final int expiresIn;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('رمز استبدال المكافأة'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QrImageView(data: code, size: 220, backgroundColor: Colors.white),
        const SizedBox(height: 12),
        SelectableText(code, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text('صالح لمدة $expiresIn ثانية. اعرضه على التاجر لإتمام الاستبدال.', textAlign: TextAlign.center),
      ],
    ),
    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق'))],
  );
}
