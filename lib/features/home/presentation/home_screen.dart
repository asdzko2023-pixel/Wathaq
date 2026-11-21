import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/wathaq_components.dart';
import '../../stores/presentation/stores_screen.dart';
import '../../rewards/presentation/rewards_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/home_repository.dart';
import '../providers/home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(homeDashboardProvider);
    final Widget page = switch (_selectedTab) {
      0 => dashboard.when(
        loading: () => const _HomeLoading(),
        error: (error, _) => _HomeError(
          message: HomeScreen._friendlyError(error),
          onRetry: () => ref.invalidate(homeDashboardProvider),
        ),
        data: (data) => _HomeContent(
          data: data,
          onRefresh: () async => ref.invalidate(homeDashboardProvider),
        ),
      ),
      1 => const StoresScreen(),
      2 => const RewardsScreen(),
      _ => const _ProfileScreen(),
    };

    return Scaffold(
      body: SafeArea(child: page),
      bottomNavigationBar: _CustomerNavigation(
        selectedIndex: _selectedTab,
        onSelected: (index) => setState(() => _selectedTab = index),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'امسح رمز المتجر',
        onPressed: () => HomeScreen._showScanInfo(context),
        backgroundColor: context.wt.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.qr_code_scanner_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  static String _friendlyError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('socket') || message.contains('network') || message.contains('connection')) {
      return 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة ثم أعد المحاولة.';
    }
    if (message.contains('jwt') || message.contains('auth') || message.contains('sign in')) {
      return 'انتهت جلسة الدخول. سجّل الدخول مجدداً.';
    }
    return 'تعذر تحميل بياناتك حالياً. حاول مرة أخرى.';
  }

  static void _showScanInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner_rounded, size: 48),
            SizedBox(height: 12),
            Text('مسح رمز المتجر', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('سيتم تفعيل الكاميرا والتحقق من الرمز عبر خادم وثاق في المرحلة التالية.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data, required this.onRefresh});
  final HomeDashboard data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = context.wt;
    final firstName = data.displayName.split(' ').first;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
        children: [
          Row(
            children: [
              Image.asset(
                'assets/brand/logo-horizontal-transparent.png',
                width: 142,
                height: 52,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text('وثاق', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: t.primary)),
              ),
              const Spacer(),
              IconButton(tooltip: 'الإشعارات', onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
              CircleAvatar(
                radius: 23,
                backgroundColor: t.primary.withValues(alpha: .10),
                child: Icon(Icons.person_outline_rounded, color: t.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('أهلاً ${firstName}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: t.textMuted)),
          Text('رصيدك ومكافآتك في مكان واحد', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          PointsCard(
            points: data.pointsBalance,
            level: 'عضو وثاق',
            nextLevel: 'تفاصيل المستوى لاحقاً',
            progress: 0,
          ),
          const SizedBox(height: 20),
          const _QuickActions(),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'المكافآت المتاحة', action: 'عرض الكل'),
          const SizedBox(height: 12),
          if (data.rewards.isEmpty)
            const _EmptyPanel(
              icon: Icons.card_giftcard_outlined,
              title: 'لا توجد مكافآت متاحة حالياً',
              subtitle: 'ستظهر هنا المكافآت التي تنشرها المتاجر المشاركة.',
            )
          else
            ...data.rewards.map((reward) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RewardTile(reward: reward),
                )),
          const SizedBox(height: 14),
          const _SectionHeader(title: 'آخر النشاط', action: 'عرض السجل'),
          const SizedBox(height: 12),
          if (data.activities.isEmpty)
            const _EmptyPanel(
              icon: Icons.history_rounded,
              title: 'لم تبدأ رحلتك بعد',
              subtitle: 'عند كسب النقاط أو استبدال المكافآت ستظهر عملياتك هنا.',
            )
          else
            ...data.activities.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActivityEntryTile(entry: entry),
                )),
          const SizedBox(height: 12),
          Text(
            'مشترك في ${data.programCount} برنامج ولاء',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textMuted),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final t = context.wt;
    const actions = [
      (Icons.storefront_rounded, 'متاجري'),
      (Icons.local_offer_rounded, 'عروضي'),
      (Icons.card_giftcard_rounded, 'مكافآتي'),
    ];
    return Row(
      children: actions.map((action) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Semantics(
            button: true,
            label: action.$2,
            child: Container(
              constraints: const BoxConstraints(minHeight: 92),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.outline),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.$1, size: 28, color: t.primary),
                  const SizedBox(height: 7),
                  Text(action.$2, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
          ),
        ),
      )).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});
  final String title;
  final String action;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          TextButton(onPressed: () {}, child: Text(action)),
        ],
      );
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.reward});
  final RewardPreview reward;

  @override
  Widget build(BuildContext context) {
    final t = context.wt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: t.gold.withValues(alpha: .18),
            child: Icon(Icons.redeem_rounded, color: t.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${reward.merchantName}${reward.description.isEmpty ? '' : ' • ${reward.description}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textMuted),
                ),
              ],
            ),
          ),
          if (reward.pointsCost != null)
            Text(
              '${NumberFormat.decimalPattern().format(reward.pointsCost)} نقطة',
              style: TextStyle(color: t.primary, fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}

class _ActivityEntryTile extends StatelessWidget {
  const _ActivityEntryTile({required this.entry});
  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    return ActivityTile(
      title: entry.title,
      detail: '${entry.subtitle} • ${DateFormat('dd/MM • HH:mm').format(entry.createdAt)}',
      time: DateFormat('dd/MM • HH:mm').format(entry.createdAt),
      points: entry.pointsDelta,
      icon: entry.kind == 'redeem' ? Icons.redeem_rounded : Icons.stars_rounded,
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.wt;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: t.primary),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          AppSkeleton(height: 52),
          SizedBox(height: 24),
          AppSkeleton(height: 190),
          SizedBox(height: 18),
          AppSkeleton(height: 92),
          SizedBox(height: 24),
          AppSkeleton(height: 76),
          SizedBox(height: 12),
          AppSkeleton(height: 76),
        ],
      );
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: context.wt.textMuted),
              const SizedBox(height: 16),
              Text('تعذر تحميل البيانات', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
}

class _CustomerNavigation extends StatelessWidget {
  const _CustomerNavigation({required this.selectedIndex, required this.onSelected});
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => BottomAppBar(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home_rounded, label: 'الرئيسية', selected: selectedIndex == 0, onTap: () => onSelected(0)),
            _NavItem(icon: Icons.storefront_rounded, label: 'المتاجر', selected: selectedIndex == 1, onTap: () => onSelected(1)),
            const SizedBox(width: 52),
            _NavItem(icon: Icons.card_giftcard_rounded, label: 'المكافآت', selected: selectedIndex == 2, onTap: () => onSelected(2)),
            _NavItem(icon: Icons.person_outline_rounded, label: 'حسابي', selected: selectedIndex == 3, onTap: () => onSelected(3)),
          ],
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.onTap, this.selected = false});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.wt;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 62,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? t.gold : t.primary, size: 24),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(color: selected ? t.gold : t.text, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(radius: 38, backgroundColor: context.wt.primary.withValues(alpha: .10),
            child: Icon(Icons.person_outline_rounded, size: 42, color: context.wt.primary)),
          const SizedBox(height: 12),
          Text(user?.userMetadata?['full_name'] as String? ?? 'مستخدم وثاق',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          Text(email, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.wt.textMuted)),
          const SizedBox(height: 24),
          ListTile(leading: const Icon(Icons.language_rounded), title: const Text('اللغة'), subtitle: const Text('العربية')),
          ListTile(leading: const Icon(Icons.notifications_outlined), title: const Text('الإشعارات')),
          ListTile(leading: const Icon(Icons.security_rounded), title: const Text('الأمان')),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
