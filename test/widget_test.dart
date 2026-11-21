import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wathaq/app.dart';
import 'package:wathaq/core/theme/wathaq_theme.dart';
import 'package:wathaq/features/home/data/home_repository.dart';
import 'package:wathaq/features/home/presentation/home_screen.dart';
import 'package:wathaq/features/home/providers/home_providers.dart';

void main() {
  testWidgets('app asks for secure Supabase build configuration when absent', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WathaqApp()));
    expect(find.text('يلزم إعداد اتصال وثاق'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });

  testWidgets('customer home renders a real empty-account state', (tester) async {
    const dashboard = HomeDashboard(
      displayName: 'ضيف وثاق',
      pointsBalance: 0,
      programCount: 0,
      activities: [],
      rewards: [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDashboardProvider.overrideWith((ref) async => dashboard),
        ],
        child: MaterialApp(
          theme: WathaqTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('رصيد نقاطك'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('لم تبدأ رحلتك بعد'), 280, scrollable: find.byType(Scrollable).first);
    expect(find.text('لم تبدأ رحلتك بعد'), findsOneWidget);
    expect(find.text('امسح رمز المتجر'), findsOneWidget);
  });
}
