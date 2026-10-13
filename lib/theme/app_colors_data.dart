import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// AppColorsData — ThemeExtension chứa toàn bộ color token của app.
///
/// Cách dùng trong widget:
///   final c = Theme.of(context).appColors;
///   Container(color: c.background)
///
/// Extension helper:
///   extension ThemeDataX on ThemeData { ... }  ← ở cuối file
/// ════════════════════════════════════════════════════════════════════════════
class AppColorsData extends ThemeExtension<AppColorsData> {
  const AppColorsData({
    // ── Brand ──────────────────────────────────────────────────────────────
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.secondary,
    required this.secondaryDark,
    required this.tertiary,
    required this.tertiaryDark,

    // ── Background / Surface ───────────────────────────────────────────────
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.card,
    required this.cardHover,

    // ── Text ──────────────────────────────────────────────────────────────
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,

    // ── Divider / Border ──────────────────────────────────────────────────
    required this.divider,
    required this.border,

    // ── Glass / Frost ─────────────────────────────────────────────────────
    required this.glassBg,
    required this.glassBorder,

    // ── Accent ────────────────────────────────────────────────────────────
    required this.accentCyan,
    required this.accentMagenta,
    required this.accentPink,

    // ── On-Player (layer trắng/tối phủ lên album art) ─────────────────────
    required this.onPlayer,
    required this.onPlayerHigh,
    required this.onPlayerMedium,
    required this.onPlayerLow,
    required this.onPlayerSubtle,
    required this.onPlayerMinimal,
    required this.onPlayerGhost,
    required this.onPlayerGhostBg,

    // ── Scrim / Overlay ───────────────────────────────────────────────────
    required this.scrimDark,
    required this.scrimMedium,
    required this.scrimLight,
    required this.scrimSubtle,
    required this.scrimStrong,

    // ── Semantic (trạng thái) ─────────────────────────────────────────────
    required this.success,
    required this.warning,
    required this.error,

    // ── Gradients ─────────────────────────────────────────────────────────
    required this.primaryGradient,
    required this.tertiaryGradient,
    required this.backgroundGradient,
    required this.recentlyPlayedGradient,
    required this.mostPlayedGradient,
    required this.favoritesGradient,
    required this.randomMixGradient,
    required this.avatarButton,
    required this.successGradient,
    required this.disabledGradient,

    // ── Meta ──────────────────────────────────────────────────────────────
    required this.brightness,
  });

  // ── Brand ────────────────────────────────────────────────────────────────
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color secondary;
  final Color secondaryDark;
  final Color tertiary;
  final Color tertiaryDark;

  // ── Background / Surface ─────────────────────────────────────────────────
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color card;
  final Color cardHover;

  // ── Text ─────────────────────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  // ── Divider / Border ─────────────────────────────────────────────────────
  final Color divider;
  final Color border;

  // ── Glass ─────────────────────────────────────────────────────────────────
  final Color glassBg;
  final Color glassBorder;

  // ── Accent ───────────────────────────────────────────────────────────────
  final Color accentCyan;
  final Color accentMagenta;
  final Color accentPink;

  // ── On-Player ─────────────────────────────────────────────────────────────
  final Color onPlayer;
  final Color onPlayerHigh;
  final Color onPlayerMedium;
  final Color onPlayerLow;
  final Color onPlayerSubtle;
  final Color onPlayerMinimal;
  final Color onPlayerGhost;
  final Color onPlayerGhostBg;

  // ── Scrim ─────────────────────────────────────────────────────────────────
  final Color scrimDark;
  final Color scrimMedium;
  final Color scrimLight;
  final Color scrimSubtle;
  final Color scrimStrong;

  // ── Semantic ──────────────────────────────────────────────────────────────
  final Color success;
  final Color warning;
  final Color error;

  // ── Gradients ─────────────────────────────────────────────────────────────
  final LinearGradient primaryGradient;
  final LinearGradient tertiaryGradient;
  final LinearGradient backgroundGradient;
  final LinearGradient recentlyPlayedGradient;
  final LinearGradient mostPlayedGradient;
  final LinearGradient favoritesGradient;
  final LinearGradient randomMixGradient;
  final LinearGradient avatarButton;
  final LinearGradient successGradient;
  final LinearGradient disabledGradient;

  // ── Meta ─────────────────────────────────────────────────────────────────
  final Brightness brightness;
  bool get isDark => brightness == Brightness.dark;

  // Foreground on the full-screen player, separate from white-on-art/brand.
  Color get playerForeground => isDark ? onPlayer : textPrimary;
  Color get playerHigh => isDark ? onPlayerHigh : textSecondary;
  Color get playerSubtle => isDark ? onPlayerSubtle : textTertiary;
  Color get playerSecondary => isDark ? onPlayerMedium : textSecondary;
  Color get playerMuted => isDark ? onPlayerLow : textTertiary;
  Color get playerHint => isDark ? onPlayerMinimal : textTertiary;
  Color get playerTrack => isDark ? onPlayerMinimal : border;

  // ─────────────────────────────────────────────────────────────────────────
  // ThemeExtension overrides
  // ─────────────────────────────────────────────────────────────────────────

  @override
  AppColorsData copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? secondary,
    Color? secondaryDark,
    Color? tertiary,
    Color? tertiaryDark,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? card,
    Color? cardHover,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? divider,
    Color? border,
    Color? glassBg,
    Color? glassBorder,
    Color? accentCyan,
    Color? accentMagenta,
    Color? accentPink,
    Color? onPlayer,
    Color? onPlayerHigh,
    Color? onPlayerMedium,
    Color? onPlayerLow,
    Color? onPlayerSubtle,
    Color? onPlayerMinimal,
    Color? onPlayerGhost,
    Color? onPlayerGhostBg,
    Color? scrimDark,
    Color? scrimMedium,
    Color? scrimLight,
    Color? scrimSubtle,
    Color? scrimStrong,
    Color? success,
    Color? warning,
    Color? error,
    LinearGradient? primaryGradient,
    LinearGradient? tertiaryGradient,
    LinearGradient? backgroundGradient,
    LinearGradient? recentlyPlayedGradient,
    LinearGradient? mostPlayedGradient,
    LinearGradient? favoritesGradient,
    LinearGradient? randomMixGradient,
    LinearGradient? avatarButton,
    LinearGradient? successGradient,
    LinearGradient? disabledGradient,
    Brightness? brightness,
  }) {
    return AppColorsData(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      secondary: secondary ?? this.secondary,
      secondaryDark: secondaryDark ?? this.secondaryDark,
      tertiary: tertiary ?? this.tertiary,
      tertiaryDark: tertiaryDark ?? this.tertiaryDark,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      card: card ?? this.card,
      cardHover: cardHover ?? this.cardHover,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      divider: divider ?? this.divider,
      border: border ?? this.border,
      glassBg: glassBg ?? this.glassBg,
      glassBorder: glassBorder ?? this.glassBorder,
      accentCyan: accentCyan ?? this.accentCyan,
      accentMagenta: accentMagenta ?? this.accentMagenta,
      accentPink: accentPink ?? this.accentPink,
      onPlayer: onPlayer ?? this.onPlayer,
      onPlayerHigh: onPlayerHigh ?? this.onPlayerHigh,
      onPlayerMedium: onPlayerMedium ?? this.onPlayerMedium,
      onPlayerLow: onPlayerLow ?? this.onPlayerLow,
      onPlayerSubtle: onPlayerSubtle ?? this.onPlayerSubtle,
      onPlayerMinimal: onPlayerMinimal ?? this.onPlayerMinimal,
      onPlayerGhost: onPlayerGhost ?? this.onPlayerGhost,
      onPlayerGhostBg: onPlayerGhostBg ?? this.onPlayerGhostBg,
      scrimDark: scrimDark ?? this.scrimDark,
      scrimMedium: scrimMedium ?? this.scrimMedium,
      scrimLight: scrimLight ?? this.scrimLight,
      scrimSubtle: scrimSubtle ?? this.scrimSubtle,
      scrimStrong: scrimStrong ?? this.scrimStrong,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      tertiaryGradient: tertiaryGradient ?? this.tertiaryGradient,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      recentlyPlayedGradient:
          recentlyPlayedGradient ?? this.recentlyPlayedGradient,
      mostPlayedGradient: mostPlayedGradient ?? this.mostPlayedGradient,
      favoritesGradient: favoritesGradient ?? this.favoritesGradient,
      randomMixGradient: randomMixGradient ?? this.randomMixGradient,
      avatarButton: avatarButton ?? this.avatarButton,
      successGradient: successGradient ?? this.successGradient,
      disabledGradient: disabledGradient ?? this.disabledGradient,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  AppColorsData lerp(AppColorsData? other, double t) {
    if (other == null) return this;
    return AppColorsData(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryDark: Color.lerp(secondaryDark, other.secondaryDark, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      tertiaryDark: Color.lerp(tertiaryDark, other.tertiaryDark, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardHover: Color.lerp(cardHover, other.cardHover, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      border: Color.lerp(border, other.border, t)!,
      glassBg: Color.lerp(glassBg, other.glassBg, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t)!,
      accentMagenta: Color.lerp(accentMagenta, other.accentMagenta, t)!,
      accentPink: Color.lerp(accentPink, other.accentPink, t)!,
      onPlayer: Color.lerp(onPlayer, other.onPlayer, t)!,
      onPlayerHigh: Color.lerp(onPlayerHigh, other.onPlayerHigh, t)!,
      onPlayerMedium: Color.lerp(onPlayerMedium, other.onPlayerMedium, t)!,
      onPlayerLow: Color.lerp(onPlayerLow, other.onPlayerLow, t)!,
      onPlayerSubtle: Color.lerp(onPlayerSubtle, other.onPlayerSubtle, t)!,
      onPlayerMinimal: Color.lerp(onPlayerMinimal, other.onPlayerMinimal, t)!,
      onPlayerGhost: Color.lerp(onPlayerGhost, other.onPlayerGhost, t)!,
      onPlayerGhostBg: Color.lerp(onPlayerGhostBg, other.onPlayerGhostBg, t)!,
      scrimDark: Color.lerp(scrimDark, other.scrimDark, t)!,
      scrimMedium: Color.lerp(scrimMedium, other.scrimMedium, t)!,
      scrimLight: Color.lerp(scrimLight, other.scrimLight, t)!,
      scrimSubtle: Color.lerp(scrimSubtle, other.scrimSubtle, t)!,
      scrimStrong: Color.lerp(scrimStrong, other.scrimStrong, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      primaryGradient:
          LinearGradient.lerp(primaryGradient, other.primaryGradient, t)!,
      tertiaryGradient:
          LinearGradient.lerp(tertiaryGradient, other.tertiaryGradient, t)!,
      backgroundGradient:
          LinearGradient.lerp(backgroundGradient, other.backgroundGradient, t)!,
      recentlyPlayedGradient:
          LinearGradient.lerp(
            recentlyPlayedGradient,
            other.recentlyPlayedGradient,
            t,
          )!,
      mostPlayedGradient:
          LinearGradient.lerp(mostPlayedGradient, other.mostPlayedGradient, t)!,
      favoritesGradient:
          LinearGradient.lerp(favoritesGradient, other.favoritesGradient, t)!,
      randomMixGradient:
          LinearGradient.lerp(randomMixGradient, other.randomMixGradient, t)!,
      avatarButton: LinearGradient.lerp(avatarButton, other.avatarButton, t)!,
      successGradient:
          LinearGradient.lerp(successGradient, other.successGradient, t)!,
      disabledGradient:
          LinearGradient.lerp(disabledGradient, other.disabledGradient, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Extension — shortcut để truy cập trong bất kỳ widget nào
//
//   final c = context.appColors;
//   final c = Theme.of(context).appColors;  // cũng được
// ════════════════════════════════════════════════════════════════════════════
extension AppColorsX on BuildContext {
  AppColorsData get appColors =>
      Theme.of(this).extension<AppColorsData>() ?? AppColorPresets.dark;
}

extension ThemeDataAppColorsX on ThemeData {
  AppColorsData get appColors =>
      extension<AppColorsData>() ?? AppColorPresets.dark;
}

// ════════════════════════════════════════════════════════════════════════════
// AppColorPresets — 3 bộ màu sẵn có
// ════════════════════════════════════════════════════════════════════════════
abstract class AppColorPresets {
  AppColorPresets._();

  // ─────────────────────────────────────────────────────────────────────────
  // DARK  (mặc định hiện tại)
  // ─────────────────────────────────────────────────────────────────────────
  static const AppColorsData dark = AppColorsData(
    brightness: Brightness.dark,

    primary: Color(0xFF9D50FF),
    primaryDark: Color(0xFF7B2FE0),
    primaryLight: Color(0xFFBB82FF),
    secondary: Color(0xFF9B5CBF),
    secondaryDark: Color(0xFF7A3D9E),
    tertiary: Color(0xFFC25169),
    tertiaryDark: Color(0xFFA03050),

    background: Color(0xFF080808),
    surface: Color(0xFF111111),
    surfaceElevated: Color(0xFF191919),
    card: Color(0xFF1C1C1E),
    cardHover: Color(0xFF242426),

    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    textTertiary: Color(0x80FFFFFF),
    textDisabled: Color(0x4DFFFFFF),

    divider: Color(0x18FFFFFF),
    border: Color(0x22FFFFFF),

    glassBg: Color(0x1AFFFFFF),
    glassBorder: Color(0x26FFFFFF),

    accentCyan: Color(0xFF00BCD4),
    accentMagenta: Color(0xFFE040FB),
    accentPink: Color(0xFFE91E63),

    onPlayer: Color(0xFFFFFFFF),
    onPlayerHigh: Color(0xB3FFFFFF),
    onPlayerMedium: Color(0x99FFFFFF),
    onPlayerLow: Color(0x8AFFFFFF),
    onPlayerSubtle: Color(0x61FFFFFF),
    onPlayerMinimal: Color(0x3DFFFFFF),
    onPlayerGhost: Color(0x1FFFFFFF),
    onPlayerGhostBg: Color(0x14FFFFFF),

    scrimDark: Color(0x8C000000),
    scrimMedium: Color(0x80000000),
    scrimLight: Color(0x73000000),
    scrimSubtle: Color(0x4D000000),
    scrimStrong: Color(0xBF000000),

    success: Color(0xFF34C759),
    warning: Color(0xFFFF9F0A),
    error: Color(0xFFFF3B30),

    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF9D50FF), Color(0xFF9B5CBF)],
    ),
    tertiaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFC25169), Color(0xFF9B5CBF)],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0E0A18), Color(0xFF080808)],
    ),
    recentlyPlayedGradient: LinearGradient(
      colors: [Color(0xFF9D50FF), Color(0xFF9B5CBF)],
    ),
    mostPlayedGradient: LinearGradient(
      colors: [Color(0xFFE040FB), Color(0xFF9B5CBF)],
    ),
    favoritesGradient: LinearGradient(
      colors: [Color(0xFFC25169), Color(0xFFE91E63)],
    ),
    randomMixGradient: LinearGradient(
      colors: [Color(0xFF00BCD4), Color(0xFF9D50FF)],
    ),
    avatarButton: LinearGradient(
      colors: [Color(0xFF9D50FF), Color(0xFFC25169)],
    ),
    successGradient: LinearGradient(
      colors: [Color(0xFF34C759), Color(0xFF30D158)],
    ),
    disabledGradient: LinearGradient(
      colors: [Color(0xFF444444), Color(0xFF333333)],
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // AMOLED  (pure black, màu sắc vivid hơn)
  // ─────────────────────────────────────────────────────────────────────────
  static const AppColorsData amoled = AppColorsData(
    brightness: Brightness.dark,

    primary: Color(0xFFAA6FFF), // sáng hơn dark một chút để nổi trên black
    primaryDark: Color(0xFF8840FF),
    primaryLight: Color(0xFFCC99FF),
    secondary: Color(0xFFAA70D0),
    secondaryDark: Color(0xFF8850B0),
    tertiary: Color(0xFFD4607A),
    tertiaryDark: Color(0xFFB04060),

    background: Color(0xFF000000), // pure black — AMOLED tiết kiệm pin
    surface: Color(0xFF090909),
    surfaceElevated: Color(0xFF121212),
    card: Color(0xFF141414),
    cardHover: Color(0xFF1C1C1C),

    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xCCFFFFFF), // cao hơn dark (80%) để dễ đọc
    textTertiary: Color(0x99FFFFFF),
    textDisabled: Color(0x55FFFFFF),

    divider: Color(0x12FFFFFF),
    border: Color(0x1AFFFFFF),

    glassBg: Color(0x14FFFFFF),
    glassBorder: Color(0x20FFFFFF),

    accentCyan: Color(0xFF00D9F5), // vivid hơn trên nền đen
    accentMagenta: Color(0xFFF050FF),
    accentPink: Color(0xFFFF2D6B),

    onPlayer: Color(0xFFFFFFFF),
    onPlayerHigh: Color(0xCCFFFFFF),
    onPlayerMedium: Color(0xAAFFFFFF),
    onPlayerLow: Color(0x99FFFFFF),
    onPlayerSubtle: Color(0x70FFFFFF),
    onPlayerMinimal: Color(0x45FFFFFF),
    onPlayerGhost: Color(0x22FFFFFF),
    onPlayerGhostBg: Color(0x18FFFFFF),

    scrimDark: Color(0x99000000),
    scrimMedium: Color(0x8C000000),
    scrimLight: Color(0x80000000),
    scrimSubtle: Color(0x59000000),
    scrimStrong: Color(0xBF000000),

    success: Color(0xFF34C759),
    warning: Color(0xFFFF9F0A),
    error: Color(0xFFFF3B30),

    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFAA6FFF), Color(0xFFAA70D0)],
    ),
    tertiaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD4607A), Color(0xFFAA70D0)],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0A0515), Color(0xFF000000)],
    ),
    recentlyPlayedGradient: LinearGradient(
      colors: [Color(0xFFAA6FFF), Color(0xFFAA70D0)],
    ),
    mostPlayedGradient: LinearGradient(
      colors: [Color(0xFFF050FF), Color(0xFFAA70D0)],
    ),
    favoritesGradient: LinearGradient(
      colors: [Color(0xFFD4607A), Color(0xFFFF2D6B)],
    ),
    randomMixGradient: LinearGradient(
      colors: [Color(0xFF00D9F5), Color(0xFFAA6FFF)],
    ),
    avatarButton: LinearGradient(
      colors: [Color(0xFF9D50FF), Color(0xFFC25169)],
    ),
    successGradient: LinearGradient(
      colors: [Color(0xFF34C759), Color(0xFF30D158)],
    ),
    disabledGradient: LinearGradient(
      colors: [Color(0xFF3A3A3A), Color(0xFF2A2A2A)],
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // LIGHT  (nền trắng, primary vẫn là purple)
  // ─────────────────────────────────────────────────────────────────────────
  static const AppColorsData light = AppColorsData(
    brightness: Brightness.light,

    primary: Color(0xFF7C3AED), // violet đậm hơn để contrast trên nền trắng
    primaryDark: Color(0xFF5B21B6),
    primaryLight: Color(0xFF9D5FF0),
    secondary: Color(0xFF8B5CF6),
    secondaryDark: Color(0xFF6D28D9),
    tertiary: Color(0xFFBE3A5A),
    tertiaryDark: Color(0xFF9B1C3E),

    background: Color(0xFFF8F7FC), // trắng xám nhẹ, mắt dễ chịu hơn pure white
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF3F1FA),
    card: Color(0xFFFFFFFF),
    cardHover: Color(0xFFEDE9F8),

    textPrimary: Color(0xFF12101A), // gần đen, không phải pure black
    textSecondary: Color(0xFF3D3650),
    textTertiary: Color(0xFF706885),
    textDisabled: Color(0xFFB0A8C8),

    divider: Color(0x1A12101A),
    border: Color(0x2212101A),

    glassBg: Color(0x1A7C3AED), // primary tinted glass
    glassBorder: Color(0x267C3AED),

    accentCyan: Color(0xFF0097A7),
    accentMagenta: Color(0xFFAD1457),
    accentPink: Color(0xFFC2185B),

    // On-player: dùng màu tối vì album art vẫn blur nhưng nền sáng hơn
    // (NowPlayingScreen vẫn render album art làm bg → giữ onPlayer = white)
    onPlayer: Color(0xFFFFFFFF),
    onPlayerHigh: Color(0xCCFFFFFF),
    onPlayerMedium: Color(0xAAFFFFFF),
    onPlayerLow: Color(0x99FFFFFF),
    onPlayerSubtle: Color(0x70FFFFFF),
    onPlayerMinimal: Color(0x45FFFFFF),
    onPlayerGhost: Color(0x22FFFFFF),
    onPlayerGhostBg: Color(0x18FFFFFF),

    // Scrim nhẹ hơn — nền sáng nên không cần overlay dày
    scrimDark: Color(0x70000000),
    scrimMedium: Color(0x60000000),
    scrimLight: Color(0x50000000),
    scrimSubtle: Color(0x30000000),
    // Lớp phủ đậm cho lời bài hát trên album art — giữ tối ở mọi theme
    scrimStrong: Color(0xBF000000),

    success: Color(0xFF34C759),
    warning: Color(0xFFFF9500), // cam iOS light, tương phản hơn trên nền sáng
    error: Color(0xFFFF3B30),

    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    tertiaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFBE3A5A), Color(0xFF8B5CF6)],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF0EDF9), Color(0xFFF8F7FC)],
    ),
    recentlyPlayedGradient: LinearGradient(
      colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    mostPlayedGradient: LinearGradient(
      colors: [Color(0xFFAD1457), Color(0xFF8B5CF6)],
    ),
    favoritesGradient: LinearGradient(
      colors: [Color(0xFFBE3A5A), Color(0xFFC2185B)],
    ),
    randomMixGradient: LinearGradient(
      colors: [Color(0xFF0097A7), Color(0xFF7C3AED)],
    ),
    avatarButton: LinearGradient(
      colors: [Color(0xFF9D50FF), Color(0xFFC25169)],
    ),
    successGradient: LinearGradient(
      colors: [Color(0xFF34C759), Color(0xFF30D158)],
    ),
    disabledGradient: LinearGradient(
      colors: [Color(0xFFC4BDD6), Color(0xFFB0A8C8)],
    ),
  );
}
