import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Scoped semantic colors. Never depends on mutable global theme state.
class AppPalette {
  const AppPalette(this.isDark);
  final bool isDark;
  Color get background =>
      isDark ? const Color(0xFF0E1713) : AppColors.background;
  Color get backgroundDeep =>
      isDark ? const Color(0xFF101F1B) : AppColors.backgroundDeep;
  Color get surface => isDark ? const Color(0xFF18251E) : AppColors.surface;
  Color get surfaceElevated =>
      isDark ? const Color(0xFF223229) : AppColors.surfaceElevated;
  Color get surfaceHighlight =>
      isDark ? const Color(0xFF2C3D32) : AppColors.surfaceHighlight;
  Color get primary => isDark ? const Color(0xFF9ADBB5) : AppColors.primary;
  Color get primaryLight =>
      isDark ? const Color(0xFFB9E9CA) : AppColors.primaryLight;
  Color get primaryDark =>
      isDark ? const Color(0xFF80CAA0) : AppColors.primaryDark;
  Color get primaryDeep =>
      isDark ? const Color(0xFF80CAA0) : AppColors.primaryDeep;
  Color get primaryInk =>
      isDark ? const Color(0xFF775521) : AppColors.primaryInk;
  Color get onPrimary => isDark ? const Color(0xFF10291C) : AppColors.onPrimary;
  Color get accent => isDark ? const Color(0xFF8EC7F0) : AppColors.accent;
  Color get accentLight =>
      isDark ? const Color(0xFFA6D2F2) : AppColors.accentLight;
  Color get violet => isDark ? const Color(0xFFCBB4ED) : AppColors.violet;
  Color get success => isDark ? const Color(0xFF93D6AD) : AppColors.success;
  Color get successLight =>
      isDark ? const Color(0xFFABE5BF) : AppColors.successLight;
  Color get successDeep =>
      isDark ? const Color(0xFF8CCDA4) : AppColors.successDeep;
  Color get warning => isDark ? const Color(0xFFF0CE88) : AppColors.warning;
  Color get danger => isDark ? const Color(0xFFFFA9A3) : AppColors.danger;
  Color get dangerLight =>
      isDark ? const Color(0xFFFFBCB7) : AppColors.dangerLight;
  Color get textPrimary =>
      isDark ? const Color(0xFFF0F5EE) : AppColors.textPrimary;
  Color get textSecondary =>
      isDark ? const Color(0xFFB4C4B8) : AppColors.textSecondary;
  Color get textTertiary =>
      isDark ? const Color(0xFFAABCAE) : AppColors.textTertiary;
  Color get divider => isDark ? const Color(0xFF35463A) : AppColors.divider;
  Color get border => isDark ? const Color(0xFF304136) : AppColors.border;
  Color get borderStrong =>
      isDark ? const Color(0xFF526657) : AppColors.borderStrong;
  Color get handle => isDark ? const Color(0xFF687D6E) : AppColors.handle;
  Color get scrim => isDark ? const Color(0x99000000) : AppColors.scrim;

  /// Peak of the skeleton shimmer: a faint light sweep on dark surfaces, a
  /// clearer one on light surfaces (where 7 % white would not show).
  Color get shimmer =>
      isDark ? const Color(0x12FFFFFF) : const Color(0x8CFFFFFF);

  /// Quiet backdrop of a list row's icon tile.
  Color get iconTile => isDark ? const Color(0x0FFFFFFF) : surfaceElevated;
}

extension AppThemeContext on BuildContext {
  AppPalette get colors =>
      AppPalette(Theme.of(this).brightness == Brightness.dark);
  AppTypography get textStyles => AppTypography(colors);
  AppGradientPalette get gradients => AppGradientPalette(colors);
}

class AppTypography {
  const AppTypography(this.colors);
  final AppPalette colors;
  TextStyle get display =>
      AppTextStyles.display.copyWith(color: colors.textPrimary);
  TextStyle get displaySmall =>
      AppTextStyles.displaySmall.copyWith(color: colors.textPrimary);
  TextStyle get headline =>
      AppTextStyles.headline.copyWith(color: colors.textPrimary);
  TextStyle get title =>
      AppTextStyles.title.copyWith(color: colors.textPrimary);
  TextStyle get titleSmall =>
      AppTextStyles.titleSmall.copyWith(color: colors.textPrimary);
  TextStyle get body => AppTextStyles.body.copyWith(color: colors.textPrimary);
  TextStyle get bodyStrong =>
      AppTextStyles.bodyStrong.copyWith(color: colors.textPrimary);
  TextStyle get bodySmall =>
      AppTextStyles.bodySmall.copyWith(color: colors.textSecondary);
  TextStyle get label =>
      AppTextStyles.label.copyWith(color: colors.textPrimary);
  TextStyle get button =>
      AppTextStyles.button.copyWith(color: colors.textPrimary);
  TextStyle get caption =>
      AppTextStyles.caption.copyWith(color: colors.textSecondary);
  TextStyle get overline =>
      AppTextStyles.overline.copyWith(color: colors.textSecondary);
  TextStyle get money =>
      AppTextStyles.money.copyWith(color: colors.textPrimary);
  TextStyle get moneyLarge =>
      AppTextStyles.moneyLarge.copyWith(color: colors.textPrimary);
}

class AppGradientPalette {
  const AppGradientPalette(this.colors);
  final AppPalette colors;
  LinearGradient get gold => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colors.primaryLight, colors.primary, colors.primaryDeep],
      stops: const [0, .45, 1]);
  LinearGradient get goldSoft => colors.isDark
      ? const LinearGradient(colors: [Color(0xFF233D2D), Color(0xFF1B3024)])
      : AppGradients.goldSoft;
  LinearGradient get surface =>
      LinearGradient(colors: [colors.surfaceElevated, colors.surface]);
  LinearGradient get success => LinearGradient(
      colors: [colors.successLight, colors.success, colors.successDeep]);
}
