import 'package:flutter/material.dart';
import '../../../core/widgets/wathaq_components.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    final t = context.wt;
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: [
        _home(context), _placeholder(context, 'المتاجر', Icons.storefront_rounded),
        _placeholder(context, 'المكافآت', Icons.card_giftcard_rounded),
        _placeholder(context, 'حسابي', Icons.person_outline_rounded),
      ])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab, onDestinationSelected: (v) => setState(() => _tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront_rounded), label: 'المتاجر'),
          NavigationDestination(icon: Icon(Icons.card_giftcard_outlined), selectedIcon: Icon(Icons.card_giftcard_rounded), label: 'المكافآت'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showScanInfo(context),
        icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('امسح واكسب'),
        backgroundColor: t.primary, foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _home(BuildContext context) {
    final t = context.wt;
    return RefreshIndicator(
      onRefresh: () async { setState(() => _loading = true); await Future<void>.delayed(const Duration(milliseconds: 450)); if (mounted) setState(() => _loading = false); },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 104),
        children: [
          Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/brand/logo-horizontal-small.png', width: 112, height: 42, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text('وثاق', style: TextStyle(color: t.primary, fontSize: 23, fontWeight: FontWeight.w900)))),
            const Spacer(),
            IconButton(tooltip: 'الإشعارات', onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
            CircleAvatar(backgroundColor: t.primary.withValues(alpha: .10), child: Icon(Icons.person_outline_rounded, color: t.primary)),
          ]),
          const SizedBox(height: 18),
          Text('مساء الخير 👋', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: t.textMuted)),
          Text('أهلاً بك في وثاق', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          const PointsCard(points: 1240, level: 'ذهبي', nextLevel: 'بلاتيني', progress: .68),
          const SizedBox(height: 16),
          WathaqPrimaryButton(label: 'امسح رمز المتجر واكسب نقاطاً', icon: Icons.qr_code_scanner_rounded, onPressed: () => _showScanInfo(context)),
          const SizedBox(height: 26),
          _sectionTitle(context, 'عروض تناسبك', 'عرض الكل'),
          const SizedBox(height: 12),
          const OfferCard(title: 'مكافآت وعروض حصرية', subtitle: 'اكتشف مزايا متاجرك المفضلة'),
          const SizedBox(height: 24),
          _sectionTitle(context, 'النقاط التي تنتهي قريباً', 'التفاصيل'),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.outline)), child: Row(children: [
            Icon(Icons.hourglass_bottom_rounded, color: t.gold), const SizedBox(width: 10),
            const Expanded(child: Text('لا توجد نقاط قريبة من الانتهاء حالياً.')),
            const StatusBadge(label: 'محدّث'),
          ])),
          const SizedBox(height: 24),
          _sectionTitle(context, 'آخر النشاط', 'عرض السجل'),
          const SizedBox(height: 12),
          if (_loading) const AppSkeleton(height: 74) else ...const [
            ActivityTile(title: 'رصيدك في انتظار أول عملية', detail: 'ستظهر هنا عمليات كسب النقاط والاستبدال', time: '—', points: 0, icon: Icons.history_rounded),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String action) => Row(children: [
    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
    TextButton(onPressed: () {}, child: Text(action)),
  ]);

  Widget _placeholder(BuildContext context, String title, IconData icon) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 44, color: context.wt.primary), const SizedBox(height: 12),
    Text(title, style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 6), Text('سيتم بناء هذه الشاشة في الدفعة التالية.', style: TextStyle(color: context.wt.textMuted)),
  ]));

  void _showScanInfo(BuildContext context) => showModalBottomSheet<void>(
    context: context, showDragHandle: true, builder: (context) => const Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.qr_code_scanner_rounded, size: 48), SizedBox(height: 12),
        Text('مسح رمز المتجر', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        SizedBox(height: 8), Text('سيتم تفعيل الكاميرا وربطها برمز التحقق الآمن في ميزة المسح.'),
      ]),
    ),
  );
}
