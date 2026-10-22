import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Strength of the action colour in [AppPalette.actionWash].
const double kActionWashOpacity = 0.12;

/// Strength of the action colour in [AppPalette.actionLine].
const double kActionLineOpacity = 0.24;

/// Scoped semantic colors. Never depends on mutable global theme state.
///
/// Dark appearance (owner, 2026-10-21: the green-tinted "forest night" was
/// tiring): neutral graphite backgrounds, surfaces and greys, off-white text,
/// and the brand green only as a quiet sage accent — never a tint over
/// everything. All text colours stay WCAG AA (test/theme/dark_theme_test.dart).
class AppPalette {
  const AppPalette(this.isDark);
  final bool isDark;
  Color get background =>
      isDark ? const Color(0xFF121417) : AppColors.background;
  Color get backgroundDeep =>
      isDark ? const Color(0xFF0E1012) : AppColors.backgroundDeep;
  Color get surface => isDark ? const Color(0xFF1B1E21) : AppColors.surface;
  Color get surfaceElevated =>
      isDark ? const Color(0xFF24282C) : AppColors.surfaceElevated;
  Color get surfaceHighlight =>
      isDark ? const Color(0xFF2E3237) : AppColors.surfaceHighlight;
  Color get primary => isDark ? const Color(0xFF8DC4A3) : AppColors.primary;
  Color get primaryLight =>
      isDark ? const Color(0xFFA5D2B7) : AppColors.primaryLight;
  Color get primaryDark =>
      isDark ? const Color(0xFF7AB693) : AppColors.primaryDark;
  Color get primaryDeep =>
      isDark ? const Color(0xFF7AB693) : AppColors.primaryDeep;
  Color get primaryInk =>
      isDark ? const Color(0xFF775521) : AppColors.primaryInk;
  Color get onPrimary => isDark ? const Color(0xFF0F2418) : AppColors.onPrimary;
  Color get accent => isDark ? const Color(0xFF8EC7F0) : AppColors.accent;
  Color get accentLight =>
      isDark ? const Color(0xFFA6D2F2) : AppColors.accentLight;
  Color get violet => isDark ? const Color(0xFFCBB4ED) : AppColors.violet;
  Color get success => isDark ? const Color(0xFF8CCBA6) : AppColors.success;
  Color get successLight =>
      isDark ? const Color(0xFFA6D8BA) : AppColors.successLight;
  Color get successDeep =>
      isDark ? const Color(0xFF7CBD97) : AppColors.successDeep;
  Color get warning => isDark ? const Color(0xFFF0CE88) : AppColors.warning;
  Color get danger => isDark ? const Color(0xFFFFA9A3) : AppColors.danger;
  Color get dangerLight =>
      isDark ? const Color(0xFFFFBCB7) : AppColors.dangerLight;
  Color get textPrimary =>
      isDark ? const Color(0xFFECEEF0) : AppColors.textPrimary;
  Color get textSecondary =>
      isDark ? const Color(0xFFB7BABF) : AppColors.textSecondary;
  Color get textTertiary =>
      isDark ? const Color(0xFFA6AAB0) : AppColors.textTertiary;
  Color get divider => isDark ? const Color(0xFF33383D) : AppColors.divider;
  Color get border => isDark ? const Color(0xFF2F3338) : AppColors.border;
  Color get borderStrong =>
      isDark ? const Color(0xFF4F5459) : AppColors.borderStrong;
  Color get handle => isDark ? const Color(0xFF6C7076) : AppColors.handle;
  Color get scrim => isDark ? const Color(0x99000000) : AppColors.scrim;

  /// Peak of the skeleton shimmer: a faint light sweep on dark surfaces, a
  /// clearer one on light surfaces (where 7 % white would not show).
  Color get shimmer =>
      isDark ? const Color(0x12FFFFFF) : const Color(0x8CFFFFFF);

  /// The action colour washed over a surface: the quiet tinted fill of the
  /// reward chip and the tonal button (2026-10-21).
  Color get actionWash =>
      Color.alphaBlend(primary.withValues(alpha: kActionWashOpacity), surface);

  /// Hairline around an [actionWash] fill.
  Color get actionLine => primary.withValues(alpha: kActionLineOpacity);

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
  TextStyle get pageTitle =>
      AppTextStyles.pageTitle.copyWith(color: colors.textPrimary);
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
      ? const LinearGradient(colors: [Color(0xFF1F2A25), Color(0xFF1A221F)])
      : AppGradients.goldSoft;
  LinearGradient get surface =>
      LinearGradient(colors: [colors.surfaceElevated, colors.surface]);
  LinearGradient get success => LinearGradient(
      colors: [colors.successLight, colors.success, colors.successDeep]);
}
