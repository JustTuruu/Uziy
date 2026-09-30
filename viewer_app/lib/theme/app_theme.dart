import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

export 'tokens.dart';

/// "Gold Noir" palette. Near-black base, layered surfaces, Mongolian gold.
///
/// Screens must use these tokens instead of raw hex values. All original
/// field names are kept (background, surface, surfaceElevated, primary,
/// primaryDark, accent, success, danger, textPrimary, textSecondary,
/// divider).
abstract final class AppColors {
  // Base layers ------------------------------------------------------------
  static const background = Color(0xFF0B0B0F);
  static const backgroundDeep = Color(0xFF060609);
  static const surface = Color(0xFF16161C);
  static const surfaceElevated = Color(0xFF1F1F27);
  static const surfaceHighlight = Color(0xFF292933);

  // Brand gold -------------------------------------------------------------
  static const primary = Color(0xFFFFCE00); // Mongolian gold
  static const primaryLight = Color(0xFFFFE36B);
  static const primaryDark = Color(0xFFE0B400);
  static const primaryDeep = Color(0xFFF2A900);

  /// Deep engraved gold — coin glyph, text on light gold.
  static const primaryInk = Color(0xFF7A4E00);

  /// Text / icons on gold surfaces.
  static const onPrimary = Color(0xFF0B0B0F);

  // Accents ----------------------------------------------------------------
  static const accent = Color(0xFF3B82F6);

  /// Accent for TEXT on dark / accent-tinted surfaces (AA; [accent] itself
  /// is only ~4.2:1 on its own tint).
  static const accentLight = Color(0xFF60A5FA);
  static const violet = Color(0xFF8B5CF6);

  // Semantic ---------------------------------------------------------------
  static const success = Color(0xFF22C55E);
  static const successLight = Color(0xFF4ADE80);
  static const successDeep = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  /// Danger for TEXT on dark / red-tinted surfaces (AA). Keep [danger] for
  /// icons, borders and fills.
  static const dangerLight = Color(0xFFF87171);

  // Text -------------------------------------------------------------------
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9CA3AF);

  /// Hints / tertiary labels. Still >= 4.5:1 (WCAG AA) on [background],
  /// [surface] and [surfaceElevated].
  static const textTertiary = Color(0xFF8B8B98);

  // Lines ------------------------------------------------------------------
  static const divider = Color(0xFF2A2A33);

  /// Hairline border (white @ 8%).
  static const border = Color(0x14FFFFFF);

  /// Stronger hairline (white @ 14%) — inputs, secondary buttons.
  static const borderStrong = Color(0x24FFFFFF);

  /// Bottom-sheet drag handle.
  static const handle = Color(0xFF3A3A45);

  /// Modal barrier / scrim.
  static const scrim = Color(0x99000000);
}

class AppTheme {
  AppTheme._();

  static const MenuStyle _menuStyle = MenuStyle(
    backgroundColor: WidgetStatePropertyAll(AppColors.surfaceElevated),
    surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
    shadowColor: WidgetStatePropertyAll(Colors.black),
    elevation: WidgetStatePropertyAll(8),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: AppRadii.brMd,
        side: BorderSide(color: AppColors.border),
      ),
    ),
  );

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: AppRadii.brMd,
        borderSide: BorderSide(color: color, width: width),
      );

  static WidgetStateColor _inputIconColor() =>
      WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textTertiary;
        }
        if (states.contains(WidgetState.error)) return AppColors.danger;
        if (states.contains(WidgetState.focused)) return AppColors.primary;
        return AppColors.textSecondary;
      });

  /// Deep gold container (tonal buttons, selected segments, M3 indicators).
  static const Color _goldContainer = Color(0xFF3A3000);

  static ThemeData dark() {
    // Every *Container role is set explicitly: unset, M3 falls back to the
    // base color, which leaked accent BLUE into selected SegmentedButtons,
    // ChoiceChip/FilterChip defaults, FilledButton.tonal and the Slider
    // track.
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: _goldContainer,
      onPrimaryContainer: AppColors.primaryLight,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: _goldContainer,
      onSecondaryContainer: AppColors.primaryLight,
      tertiary: AppColors.violet,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF2A1F4D),
      onTertiaryContainer: Color(0xFFDDD6FE),
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: Color(0xFF3F1517),
      onErrorContainer: Color(0xFFFECACA),
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceDim: AppColors.background,
      surfaceBright: AppColors.surfaceHighlight,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceElevated,
      surfaceContainerHighest: AppColors.surfaceHighlight,
      outline: AppColors.handle,
      outlineVariant: AppColors.divider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.textPrimary,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.primaryDeep,
      surfaceTint: Colors.transparent,
    );

    const textTheme = TextTheme(
      displayLarge: AppTextStyles.display,
      displayMedium: AppTextStyles.display,
      displaySmall: AppTextStyles.displaySmall,
      headlineLarge: AppTextStyles.displaySmall,
      headlineMedium: AppTextStyles.headline,
      headlineSmall: AppTextStyles.headline,
      titleLarge: AppTextStyles.title,
      titleMedium: AppTextStyles.titleSmall,
      titleSmall: AppTextStyles.label,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.button,
      labelMedium: AppTextStyles.label,
      labelSmall: AppTextStyles.caption,
    );

    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadii.brMd);

    // Mirrors AppButton(primary). Full-width by default (Size.fromHeight)
    // because the existing screens rely on stretched CTAs.
    final primaryButtonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(54)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22),
      ),
      shape: const WidgetStatePropertyAll(buttonShape),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      textStyle: const WidgetStatePropertyAll(AppTextStyles.button),
      backgroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.disabled)
              ? AppColors.surfaceElevated
              : AppColors.primary),
      foregroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.disabled)
              ? AppColors.textSecondary
              : AppColors.onPrimary),
      overlayColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.pressed)
              ? Colors.black.withValues(alpha: 0.08)
              : null),
      splashFactory: NoSplash.splashFactory,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surfaceElevated,
      cardColor: AppColors.surface,
      dividerColor: AppColors.divider,
      disabledColor: AppColors.textTertiary,
      hintColor: AppColors.textTertiary,
      // No ripples — iOS-style highlight only. InkWell still shows a subtle
      // pressed highlight via highlightColor.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.white.withValues(alpha: 0.05),
      hoverColor: Colors.white.withValues(alpha: 0.03),
      focusColor: AppColors.primary.withValues(alpha: 0.14),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      primaryIconTheme:
          const IconThemeData(color: AppColors.onPrimary, size: 22),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        barBackgroundColor: AppColors.surface,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: AppTextStyles.title,
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: _inputBorder(AppColors.borderStrong),
        enabledBorder: _inputBorder(AppColors.borderStrong),
        disabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.primary, 1.5),
        errorBorder: _inputBorder(AppColors.danger.withValues(alpha: 0.75)),
        focusedErrorBorder: _inputBorder(AppColors.danger, 1.5),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
        labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          final color = states.contains(WidgetState.error)
              ? AppColors.danger
              : states.contains(WidgetState.focused)
                  ? AppColors.primary
                  : AppColors.textSecondary;
          return AppTextStyles.label.copyWith(color: color);
        }),
        helperStyle: AppTextStyles.caption,
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.danger),
        // Mongolian validation copy runs long; don't cut it to one line.
        helperMaxLines: 2,
        errorMaxLines: 2,
        prefixStyle:
            AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        suffixStyle:
            AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        counterStyle: AppTextStyles.caption,
        prefixIconColor: _inputIconColor(),
        suffixIconColor: _inputIconColor(),
        iconColor: AppColors.textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.textTertiary,
          backgroundColor: AppColors.surfaceElevated,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: AppTextStyles.button,
          shape: buttonShape,
          side: const BorderSide(color: AppColors.borderStrong),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textTertiary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.brSm),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.textTertiary,
          minimumSize: const Size(44, 44),
          highlightColor: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.brLg,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: AppTextStyles.bodyStrong,
        actionTextColor: AppColors.primary,
        closeIconColor: AppColors.textSecondary,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: AppColors.scrim,
        dragHandleColor: AppColors.handle,
        dragHandleSize: Size(40, 4),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        barrierColor: AppColors.scrim,
        titleTextStyle: AppTextStyles.title,
        contentTextStyle:
            AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) {
            // Keep a disabled-but-checked box readable (dark check on grey).
            return s.contains(WidgetState.selected)
                ? AppColors.textTertiary
                : Colors.transparent;
          }
          if (s.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.onPrimary),
        side: WidgetStateBorderSide.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? const BorderSide(color: AppColors.primary, width: 1.5)
                : const BorderSide(color: AppColors.textSecondary, width: 1.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.onPrimary
                : AppColors.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.surfaceElevated),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? Colors.transparent
                : AppColors.borderStrong),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceElevated,
        selectedColor: AppColors.primary.withValues(alpha: 0.16),
        disabledColor: AppColors.surface,
        checkmarkColor: AppColors.primary,
        // Selected chips (e.g. gender picker) read gold, not just tinted.
        labelStyle: AppTextStyles.label.copyWith(
          color: WidgetStateColor.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return AppColors.textTertiary;
            if (s.contains(WidgetState.selected)) return AppColors.primary;
            return AppColors.textPrimary;
          }),
        ),
        secondaryLabelStyle:
            AppTextStyles.label.copyWith(color: AppColors.primary),
        side: WidgetStateBorderSide.resolveWith((s) => BorderSide(
              color: s.contains(WidgetState.selected)
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : AppColors.border,
            )),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        iconTheme:
            const IconThemeData(color: AppColors.textSecondary, size: 16),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        headerBackgroundColor: AppColors.surface,
        headerForegroundColor: AppColors.textPrimary,
        headerHeadlineStyle: AppTextStyles.headline,
        headerHelpStyle:
            AppTextStyles.label.copyWith(color: AppColors.textSecondary),
        weekdayStyle: AppTextStyles.caption,
        dayStyle: AppTextStyles.label,
        dividerColor: AppColors.divider,
        subHeaderForegroundColor: AppColors.textSecondary,
        dayForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return AppColors.onPrimary;
          if (s.contains(WidgetState.disabled)) {
            return AppColors.textTertiary.withValues(alpha: 0.5);
          }
          return AppColors.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.primary
                : Colors.transparent),
        dayOverlayColor: WidgetStatePropertyAll(
          AppColors.primary.withValues(alpha: 0.12),
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.onPrimary
                : AppColors.primary),
        todayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.primary
                : Colors.transparent),
        todayBorder: const BorderSide(color: AppColors.primary),
        yearStyle: AppTextStyles.label,
        yearForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return AppColors.onPrimary;
          if (s.contains(WidgetState.disabled)) {
            return AppColors.textTertiary.withValues(alpha: 0.5);
          }
          return AppColors.textPrimary;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.primary
                : Colors.transparent),
        yearOverlayColor: WidgetStatePropertyAll(
          AppColors.primary.withValues(alpha: 0.12),
        ),
        confirmButtonStyle:
            TextButton.styleFrom(foregroundColor: AppColors.primary),
        cancelButtonStyle:
            TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Colors.white.withValues(alpha: 0.10),
        circularTrackColor: Colors.transparent,
        refreshBackgroundColor: AppColors.surfaceElevated,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.32),
        selectionHandleColor: AppColors.primary,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: AppTextStyles.bodyStrong,
        subtitleTextStyle: AppTextStyles.caption,
        leadingAndTrailingTextStyle: AppTextStyles.body,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
        horizontalTitleGap: 12,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: AppColors.primary.withValues(alpha: 0.16),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  )
                : AppTextStyles.caption),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.textSecondary,
            )),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        dividerColor: Colors.transparent,
        labelStyle: AppTextStyles.label,
        unselectedLabelStyle: AppTextStyles.label,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: AppTextStyles.body,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.brMd,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.2),
        ),
        radius: const Radius.circular(8),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.danger,
        textColor: Colors.white,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        splashColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.brLg),
        extendedTextStyle: AppTextStyles.button,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
        secondaryActiveTrackColor: AppColors.primary.withValues(alpha: 0.4),
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
        activeTickMarkColor: AppColors.onPrimary.withValues(alpha: 0.4),
        inactiveTickMarkColor: Colors.white.withValues(alpha: 0.3),
        disabledActiveTrackColor: AppColors.textTertiary,
        disabledInactiveTrackColor: Colors.white.withValues(alpha: 0.08),
        disabledThumbColor: AppColors.textTertiary,
        valueIndicatorColor: AppColors.surfaceHighlight,
        valueIndicatorTextStyle: AppTextStyles.label,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppLayout.minTapTarget, AppLayout.minTapTarget),
          ),
          textStyle: const WidgetStatePropertyAll(AppTextStyles.label),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return AppColors.textTertiary;
            if (s.contains(WidgetState.selected)) return AppColors.onPrimary;
            return AppColors.textPrimary;
          }),
          iconColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.onPrimary
                  : AppColors.textSecondary),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.borderStrong),
          ),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        selectedLabelStyle:
            AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: AppTextStyles.caption,
      ),
      menuTheme: const MenuThemeData(style: _menuStyle),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: _menuStyle,
        textStyle: AppTextStyles.body,
      ),
    );
  }
}
