import 'package:flutter/material.dart';
import 'wathaq_tokens.dart';

class WathaqTheme {
  static ThemeData light() => _build(Brightness.light, WathaqTokens.light);
  static ThemeData dark() => _build(Brightness.dark, WathaqTokens.dark);

  static ThemeData _build(Brightness brightness, WathaqTokens t) {
    final scheme = ColorScheme(
      brightness: brightness, primary: t.primary, onPrimary: brightness == Brightness.light ? Colors.white : t.primaryDeep,
      secondary: t.gold, onSecondary: const Color(0xFF2B1B00),
      error: t.error, onError: Colors.white, surface: t.surface, onSurface: t.text,
    );
    return ThemeData(
      useMaterial3: true, brightness: brightness, colorScheme: scheme,
      scaffoldBackgroundColor: t.surfaceAlt,
      fontFamily: 'Tajawal',
      extensions: [t],
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.25),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.35),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.45),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ).apply(bodyColor: t.text, displayColor: t.text),
      appBarTheme: AppBarTheme(backgroundColor: t.surfaceAlt, foregroundColor: t.text, elevation: 0, centerTitle: false),
      dividerColor: t.outline,
      cardTheme: CardThemeData(color: t.surface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusLarge))),
      navigationBarTheme: NavigationBarThemeData(
        height: 76, backgroundColor: t.surface, indicatorColor: t.gold.withValues(alpha: .16),
        labelTextStyle: WidgetStateProperty.all(TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700, color: t.text)),
      ),
    );
  }
}
