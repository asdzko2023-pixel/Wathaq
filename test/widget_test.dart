import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wathaq/app.dart';

void main() {
  testWidgets('home screen renders the WATHAQ points summary', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WathaqApp()));
    await tester.pumpAndSettle();
    expect(find.text('رصيد نقاطك'), findsOneWidget);
    expect(find.text('امسح واكسب'), findsOneWidget);
  });
}
