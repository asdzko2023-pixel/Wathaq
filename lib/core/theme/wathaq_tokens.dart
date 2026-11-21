import 'package:flutter/material.dart';

@immutable
class WathaqTokens extends ThemeExtension<WathaqTokens> {
  const WathaqTokens({
    required this.primary, required this.primaryDeep, required this.gold,
    required this.goldSoft, required this.surface, required this.surfaceAlt,
    required this.text, required this.textMuted, required this.success,
    required this.error, required this.outline, required this.gradientStart,
    required this.gradientEnd, required this.shadowSoft, required this.shadowCard,
    this.space1 = 4, this.space2 = 8, this.space3 = 12, this.space4 = 16,
    this.space5 = 20, this.space6 = 24, this.radiusSmall = 12,
    this.radiusMedium = 18, this.radiusLarge = 26, this.radiusPill = 999,
  });

  final Color primary, primaryDeep, gold, goldSoft, surface, surfaceAlt;
  final Color text, textMuted, success, error, outline;
  final Color gradientStart, gradientEnd, shadowSoft, shadowCard;
  final double space1, space2, space3, space4, space5, space6;
  final double radiusSmall, radiusMedium, radiusLarge, radiusPill;

  @override
  WathaqTokens copyWith({
    Color? primary, Color? primaryDeep, Color? gold, Color? goldSoft,
    Color? surface, Color? surfaceAlt, Color? text, Color? textMuted,
    Color? success, Color? error, Color? outline, Color? gradientStart,
    Color? gradientEnd, Color? shadowSoft, Color? shadowCard,
  }) => WathaqTokens(
    primary: primary ?? this.primary, primaryDeep: primaryDeep ?? this.primaryDeep,
    gold: gold ?? this.gold, goldSoft: goldSoft ?? this.goldSoft,
    surface: surface ?? this.surface, surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    text: text ?? this.text, textMuted: textMuted ?? this.textMuted,
    success: success ?? this.success, error: error ?? this.error,
    outline: outline ?? this.outline, gradientStart: gradientStart ?? this.gradientStart,
    gradientEnd: gradientEnd ?? this.gradientEnd, shadowSoft: shadowSoft ?? this.shadowSoft,
    shadowCard: shadowCard ?? this.shadowCard,
  );

  @override
  WathaqTokens lerp(ThemeExtension<WathaqTokens>? other, double t) {
    if (other is! WathaqTokens) return this;
    return WathaqTokens(
      primary: Color.lerp(primary, other.primary, t)!, primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t)!,
      gold: Color.lerp(gold, other.gold, t)!, goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      surface: Color.lerp(surface, other.surface, t)!, surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      text: Color.lerp(text, other.text, t)!, textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!, error: Color.lerp(error, other.error, t)!,
      outline: Color.lerp(outline, other.outline, t)!, gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!, shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
      shadowCard: Color.lerp(shadowCard, other.shadowCard, t)!,
    );
  }

  static const light = WathaqTokens(
    primary: Color(0xFF4B1764), primaryDeep: Color(0xFF2B1038),
    gold: Color(0xFFD6A744), goldSoft: Color(0xFFFFE5A8),
    surface: Color(0xFFFFFBFE), surfaceAlt: Color(0xFFF6EDF5),
    text: Color(0xFF27132F), textMuted: Color(0xFF66566C),
    success: Color(0xFF087B5B), error: Color(0xFFB3261E),
    outline: Color(0xFFE4D7E5), gradientStart: Color(0xFF54206C),
    gradientEnd: Color(0xFF291035), shadowSoft: Color(0x16000000),
    shadowCard: Color(0x220F0618),
  );

  static const dark = WathaqTokens(
    primary: Color(0xFFD9B1E8), primaryDeep: Color(0xFF210D2C),
    gold: Color(0xFFE2B95C), goldSoft: Color(0xFF6D5424),
    surface: Color(0xFF1B1420), surfaceAlt: Color(0xFF2A2030),
    text: Color(0xFFFFF7FF), textMuted: Color(0xFFD2C4D6),
    success: Color(0xFF67D6B2), error: Color(0xFFFFB4AB),
    outline: Color(0xFF594B5E), gradientStart: Color(0xFF512264),
    gradientEnd: Color(0xFF1D0B27), shadowSoft: Color(0x33000000),
    shadowCard: Color(0x55000000),
  );
}
