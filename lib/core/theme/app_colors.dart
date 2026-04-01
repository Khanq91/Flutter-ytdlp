import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────
  static const Color primary = Color(0xFF9D50FF);
  static const Color primaryDark = Color(0xFF7B2FE0);
  static const Color primaryLight = Color(0xFFBB82FF);

  static const Color secondary = Color(0xFF9B5CBF);
  static const Color secondaryDark = Color(0xFF7A3D9E);

  static const Color tertiary = Color(0xFFC25169);
  static const Color tertiaryDark = Color(0xFFA03050);

  // ── Background / Surface ───────────────────────────────
  static const Color background = Color(0xFF080808);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceElevated = Color(0xFF191919);
  static const Color card = Color(0xFF1C1C1E);
  static const Color cardHover = Color(0xFF242426);

  // ── Text ───────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70%
  static const Color textTertiary = Color(0x80FFFFFF); // 50%
  static const Color textDisabled = Color(0x4DFFFFFF); // 30%

  // ── Divider / Border ──────────────────────────────────
  static const Color divider = Color(0x18FFFFFF);
  static const Color border = Color(0x22FFFFFF);

  // ── Glass ─────────────────────────────────────────────
  static const Color glassBg = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x26FFFFFF);

  // ── Gradients ─────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient tertiaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tertiary, secondary],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0E0A18), Color(0xFF080808)],
  );

  static LinearGradient dynamicGradient(Color dominantColor) {
    final hsl = HSLColor.fromColor(dominantColor);
    final darker = hsl.withLightness((hsl.lightness - 0.3).clamp(0.0, 1.0)).toColor();
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [dominantColor.withOpacity(0.6), darker.withOpacity(0.9)],
    );
  }
}
