import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/wathaq_components.dart';

final storesProvider = FutureProvider.autoDispose<List<StoreItem>>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) throw AuthException('يلزم تسجيل الدخول.');
  final merchants = await client.from('merchants')
      .select('id,name,category,description,city')
      .eq('status', 'active')
      .order('name');
  if (merchants.isEmpty) return const [];

  final ids = merchants.map((row) => row['id'] as String).toList();
  final programs = await client.from('loyalty_programs')
      .select('id,merchant_id,name,kind,description')
      .eq('state', 'active')
      .inFilter('merchant_id', ids);
  final favoriteRows = await client.from('favorites')
      .select('merchant_id')
      .eq('customer_id', user.id);
  final accountRows = await client.from('loyalty_accounts')
      .select('program_id')
      .eq('customer_id', user.id);

  final favoriteIds = favoriteRows.map((row) => row['merchant_id'] as String).toSet();
  final joinedIds = accountRows.map((row) => row['program_id'] as String).toSet();

  return merchants.map((merchant) {
    final merchantId = merchant['id'] as String;
    final storePrograms = programs.where((p) => p['merchant_id'] == merchantId).map((p) => StoreProgram(
      id: p['id'] as String,
      name: p['name'] as String,
      kind: p['kind'] as String,
      description: p['description'] as String? ?? '',
      joined: joinedIds.contains(p['id']),
    )).toList();
    return StoreItem(
      id: merchantId,
      name: merchant['name'] as String,
      category: merchant['category'] as String? ?? 'متجر مشارك',
      description: merchant['description'] as String? ?? '',
      city: merchant['city'] as String? ?? '',
      favorite: favoriteIds.contains(merchantId),
      programs: storePrograms,
    );
  }).toList();
});

class StoreProgram {
  const StoreProgram({required this.id, required this.name, required this.kind, required this.description, required this.joined});
  final String id, name, kind, description;
  final bool joined;
}

class StoreItem {
  const StoreItem({required this.id, required this.name, required this.category, required this.description, required this.city, required this.favorite, required this.programs});
  final String id, name, category, description, city;
  final bool favorite;
  final List<StoreProgram> programs;
}

class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  Future<void> _toggleFavorite(WidgetRef ref, StoreItem store) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser!;
    if (store.favorite) {
      await client.from('favorites').delete()
          .eq('customer_id', user.id).eq('merchant_id', store.id);
    } else {
      await client.from('favorites').upsert(
        {'customer_id': user.id, 'merchant_id': store.id},
        onConflict: 'customer_id,merchant_id',
      );
    }
    ref.invalidate(storesProvider);
  }

  Future<void> _joinProgram(BuildContext context, WidgetRef ref, StoreProgram program) async {
    try {
      await Supabase.instance.client.rpc('join_loyalty_program', params: {'p_program_id': program.id});
      ref.invalidate(storesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الانضمام إلى برنامج الولاء بنجاح.')));
      }
    } on PostgrestException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الانضمام: ${error.message}')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ. حاول مرة أخرى.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(storesProvider);
    final t = context.wt;
    return Scaffold(
      appBar: AppBar(title: const Text('المتاجر المشاركة')),
      body: stores.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _StoresMessage(
          icon: Icons.cloud_off_rounded,
          title: 'تعذر تحميل المتاجر',
          action: TextButton(onPressed: () => ref.invalidate(storesProvider), child: const Text('إعادة المحاولة')),
        ),
        data: (items) => items.isEmpty
            ? const _StoresMessage(icon: Icons.storefront_outlined, title: 'لا توجد متاجر مشاركة حالياً')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final store = items[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundColor: t.primary.withValues(alpha: .10), child: Icon(Icons.storefront_rounded, color: t.primary)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(store.name, style: Theme.of(context).textTheme.titleMedium),
                              Text([store.category, store.city].where((v) => v.isNotEmpty).join(' • '), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textMuted)),
                            ])),
                            IconButton(
                              tooltip: store.favorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                              onPressed: () => _toggleFavorite(ref, store),
                              icon: Icon(store.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: store.favorite ? t.error : t.primary),
                            ),
                          ],
                        ),
                        if (store.description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(store.description, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        if (store.programs.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          ...store.programs.map((program) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(program.name, style: Theme.of(context).textTheme.titleSmall),
                                Text(program.kind == 'stamps' ? 'برنامج أختام' : 'برنامج نقاط', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textMuted)),
                              ])),
                              if (program.joined)
                                const StatusBadge(label: 'مشترك')
                              else
                                OutlinedButton(
                                  onPressed: () => _joinProgram(context, ref, program),
                                  child: const Text('انضم'),
                                ),
                            ]),
                          )),
                        ] else ...[
                          const SizedBox(height: 12),
                          Text('لا يوجد برنامج ولاء نشط لهذا المتجر حالياً.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textMuted)),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _StoresMessage extends StatelessWidget {
  const _StoresMessage({required this.icon, required this.title, this.action});
  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 44, color: context.wt.textMuted), const SizedBox(height: 12), Text(title), if (action != null) action!],
  ));
}
