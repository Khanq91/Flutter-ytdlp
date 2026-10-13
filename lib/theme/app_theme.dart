import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors_data.dart'; // dynamic theme extension

// ════════════════════════════════════════════════════════════════════════════
// AppTheme — factory tạo ThemeData từ bất kỳ AppColorsData nào
// ════════════════════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  /// Gọi từ ThemeProvider.themeData — build ThemeData cho theme bất kỳ
  static ThemeData buildTheme(AppColorsData c) {
    final isDark = c.isDark;
    final base =
        isDark
            ? ThemeData.dark(useMaterial3: true)
            : ThemeData.light(useMaterial3: true);
    final outfitText = GoogleFonts.outfitTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: c.background,

      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: c.primary,
        onPrimary: Colors.white,
        secondary: c.secondary,
        onSecondary: Colors.white,
        tertiary: c.tertiary,
        onTertiary: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
        error: const Color(0xFFCF6679),
        onError: Colors.white,
      ),

      // ── Attach color extension — trái tim của hệ thống ──────────────────
      extensions: [c],

      textTheme: outfitText.copyWith(
        displayLarge: outfitText.displayLarge?.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        displayMedium: outfitText.displayMedium?.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleLarge: outfitText.titleLarge?.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleMedium: outfitText.titleMedium?.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: outfitText.bodyLarge?.copyWith(
          color: c.textSecondary,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: outfitText.bodyMedium?.copyWith(
          color: c.textSecondary,
          fontWeight: FontWeight.w300,
        ),
        labelSmall: outfitText.labelSmall?.copyWith(
          color: c.textTertiary,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.3,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.outfit(
          color: c.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.textTertiary,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        labelStyle: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.divider,
        thumbColor: isDark ? Colors.white : c.primary,
        overlayColor: c.primary.withValues(alpha: 0.15),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      iconTheme: IconThemeData(color: c.textSecondary),

      dividerTheme: DividerThemeData(color: c.divider, thickness: 0.5),

      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        modalBackgroundColor: c.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.primary;
          return c.textDisabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return c.primary.withValues(alpha: 0.35);
          }
          return c.surfaceElevated;
        }),
      ),

      splashFactory: InkRipple.splashFactory,
    );
  }

  /// Backward compat — dùng cho code cũ chưa migrate
  /// Trả về dark theme tĩnh không có ThemeExtension.
  static ThemeData get darkTheme => buildTheme(AppColorPresets.dark);
}
