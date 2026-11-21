import 'package:flutter/material.dart';
import '../theme/wathaq_tokens.dart';

extension WathaqContext on BuildContext {
  WathaqTokens get wt => Theme.of(this).extension<WathaqTokens>()!;
}

class PointsCard extends StatelessWidget {
  const PointsCard({super.key, required this.points, required this.level, required this.nextLevel, required this.progress});
  final int points; final String level, nextLevel; final double progress;
  @override
  Widget build(BuildContext context) {
    final t = context.wt;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [t.gradientStart, t.gradientEnd]),
        borderRadius: BorderRadius.circular(t.radiusLarge),
        boxShadow: [BoxShadow(color: t.shadowCard, blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('رصيد نقاطك', style: TextStyle(color: Colors.white.withValues(alpha: .86), fontSize: 14)),
            const SizedBox(height: 4),
            Text(points.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
          ])),
          Container(width: 52, height: 52, decoration: BoxDecoration(color: t.gold, shape: BoxShape.circle), child: const Icon(Icons.stars_rounded, color: Color(0xFF55380A), size: 30)),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Text('مستواك: $level', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('التالي: $nextLevel', style: TextStyle(color: Colors.white.withValues(alpha: .88), fontSize: 12)),
        ]),
        const SizedBox(height: 9),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 8, backgroundColor: Colors.white24, color: t.gold)),
      ]),
    );
  }
}

class TierProgress extends StatelessWidget {
  const TierProgress({super.key, required this.current, required this.next, required this.progress});
  final String current, next; final double progress;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Text(current, style: Theme.of(context).textTheme.titleMedium), const Spacer(), Text('المستوى التالي: $next', style: Theme.of(context).textTheme.bodyMedium)]),
    const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 8)),
  ]);
}

class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.title, required this.subtitle, this.tag = 'عرض مميز', this.onTap});
  final String title, subtitle, tag; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.wt;
    return Semantics(button: true, label: '$title، $subtitle', child: Material(
      color: t.surface, borderRadius: BorderRadius.circular(t.radiusLarge),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(t.radiusLarge), child: Container(
        padding: const EdgeInsets.all(16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusLarge), border: Border.all(color: t.outline)),
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: t.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.local_offer_rounded, color: t.primary, size: 26)),
          const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tag, style: TextStyle(color: t.gold, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 3), Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textMuted)),
          ])), const Icon(Icons.chevron_left_rounded),
        ]),
      )),
    ));
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.title, required this.detail, required this.time, required this.points, this.icon = Icons.stars_rounded});
  final String title, detail, time; final int points; final IconData icon;
  @override
  Widget build(BuildContext context) {
    final t = context.wt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(t.radiusMedium), border: Border.all(color: t.outline)),
      child: Row(children: [
        CircleAvatar(backgroundColor: t.primary.withValues(alpha: .10), child: Icon(icon, color: t.primary)),
        const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium), Text(detail, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textMuted)),
        ])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(points > 0 ? '+$points نقطة' : '—', style: TextStyle(color: points > 0 ? t.success : t.textMuted, fontWeight: FontWeight.w800)),
          Text(time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textMuted)),
        ]),
      ]),
    );
  }
}

class WathaqPrimaryButton extends StatelessWidget {
  const WathaqPrimaryButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label; final VoidCallback? onPressed; final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(height: 52, child: FilledButton.icon(
    onPressed: onPressed, icon: Icon(icon ?? Icons.arrow_forward_rounded), label: Text(label),
    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontWeight: FontWeight.w800)),
  ));
}

class WathaqSecondaryButton extends StatelessWidget {
  const WathaqSecondaryButton({super.key, required this.label, required this.onPressed});
  final String label; final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(height: 52, child: OutlinedButton(onPressed: onPressed, child: Text(label)));
}

class WathaqTextButton extends StatelessWidget {
  const WathaqTextButton({super.key, required this.label, required this.onPressed});
  final String label; final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => TextButton(onPressed: onPressed, child: Text(label));
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.positive = true});
  final String label; final bool positive;
  @override
  Widget build(BuildContext context) {
    final c = positive ? context.wt.success : context.wt.error;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: c.withValues(alpha: .10), borderRadius: BorderRadius.circular(30)), child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)));
  }
}

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, this.height = 72, this.width = double.infinity});
  final double height, width;
  @override
  Widget build(BuildContext context) => Container(height: height, width: width, decoration: BoxDecoration(color: context.wt.outline.withValues(alpha: .45), borderRadius: BorderRadius.circular(16)));
}
