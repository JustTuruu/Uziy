import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

export 'tokens.dart';
export 'theme_palette.dart';
import 'theme_palette.dart';

/// Uziy Meadow: warm paper, forest green, and clear financial hierarchy.
///
/// Screens must use these tokens instead of raw hex values. All original
/// field names are kept (background, surface, surfaceElevated, primary,
/// primaryDark, accent, success, danger, textPrimary, textSecondary,
/// divider).
abstract final class AppColors {
  // Base layers ------------------------------------------------------------
  static const background = Color(0xFFF5F7F3);
  static const backgroundDeep = Color(0xFF101F1B);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFEDF2EC);
  static const surfaceHighlight = Color(0xFFE1E9E1);

  // Brand green -------------------------------------------------------------
  static const primary = Color(0xFF145C45);
  static const primaryLight = Color(0xFF1B634C);
  static const primaryDark = Color(0xFF104C39);
  static const primaryDeep = Color(0xFF104C39);

  /// Deep engraved gold — coin glyph, text on light gold.
  static const primaryInk = Color(0xFF775521);

  /// Text / icons on forest-green action surfaces.
  static const onPrimary = Color(0xFFFFFFFF);

  // Accents ----------------------------------------------------------------
  static const accent = Color(0xFF2467A1);

  /// High-contrast text for informational surfaces.
  static const accentLight = Color(0xFF245B8A);
  static const violet = Color(0xFF72539A);

  // Semantic ---------------------------------------------------------------
  static const success = Color(0xFF12633D);
  static const successLight = Color(0xFF1B714D);
  static const successDeep = Color(0xFF125535);
  static const warning = Color(0xFF805109);
  static const danger = Color(0xFFBD3934);

  /// Danger text on light red-tinted surfaces. Keep [danger] for
  /// icons, borders and fills.
  static const dangerLight = Color(0xFFA52E2A);

  // Text -------------------------------------------------------------------
  static const textPrimary = Color(0xFF192D25);
  static const textSecondary = Color(0xFF53675C);

  /// Hints / tertiary labels. Still >= 4.5:1 (WCAG AA) on [background],
  /// [surface] and [surfaceElevated].
  static const textTertiary = Color(0xFF5D7063);

  // Lines ------------------------------------------------------------------
  static const divider = Color(0xFFDBE4DA);

  /// Quiet sage border on white surfaces.
  static const border = Color(0xFFE0E7DD);

  /// Stronger border for inputs and secondary buttons.
  static const borderStrong = Color(0xFFC4D1C3);

  /// Bottom-sheet drag handle.
  static const handle = Color(0xFFA3B3A4);

  /// Modal barrier / scrim.
  static const scrim = Color(0x99000000);
}

class AppTheme {
  AppTheme._();

  static MenuStyle _menuStyle(AppPalette colors) => MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceElevated),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.black),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: AppRadii.brMd,
            side: BorderSide(color: colors.border),
          ),
        ),
      );

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: AppRadii.brMd,
        borderSide: BorderSide(color: color, width: width),
      );

  static WidgetStateColor _inputIconColor(AppPalette colors) =>
      WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.textTertiary;
        }
        if (states.contains(WidgetState.error)) return colors.danger;
        if (states.contains(WidgetState.focused)) return colors.primary;
        return colors.textSecondary;
      });

  /// Pale sage container for tonal buttons and selected controls.
  static const Color _brandContainer = Color(0xFFE0EDE3);

  static ThemeData light() => _build(false);
  static ThemeData dark() => _build(true);

  static ThemeData _build(bool isDark) {
    final colors = AppPalette(isDark);
    final textStyles = AppTypography(colors);
    // Every *Container role is set explicitly: unset, M3 falls back to the
    // base color, which leaked accent BLUE into selected SegmentedButtons,
    // ChoiceChip/FilterChip defaults, FilledButton.tonal and the Slider
    // track.
    final scheme = ColorScheme(
      brightness: (isDark ? Brightness.dark : Brightness.light),
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: isDark ? const Color(0xFF24352B) : _brandContainer,
      onPrimaryContainer: colors.primary,
      secondary: colors.accent,
      onSecondary: colors.onPrimary,
      secondaryContainer: isDark ? const Color(0xFF24352B) : _brandContainer,
      onSecondaryContainer: colors.primary,
      tertiary: colors.violet,
      onTertiary: colors.onPrimary,
      tertiaryContainer:
          isDark ? const Color(0xFF352C45) : const Color(0xFFEDE5F5),
      onTertiaryContainer:
          isDark ? const Color(0xFFE4D4FA) : const Color(0xFF543B74),
      error: colors.danger,
      onError: colors.onPrimary,
      errorContainer:
          isDark ? const Color(0xFF482B29) : const Color(0xFFFBE8E4),
      onErrorContainer:
          isDark ? const Color(0xFFFFC7C2) : const Color(0xFF922722),
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      surfaceDim: colors.background,
      surfaceBright: colors.surfaceHighlight,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surfaceElevated,
      surfaceContainerHighest: colors.surfaceHighlight,
      outline: colors.handle,
      outlineVariant: colors.divider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: colors.textPrimary,
      onInverseSurface: colors.background,
      inversePrimary: colors.primaryDeep,
      surfaceTint: Colors.transparent,
    );

    final textTheme = TextTheme(
      displayLarge: textStyles.display,
      displayMedium: textStyles.display,
      displaySmall: textStyles.displaySmall,
      headlineLarge: textStyles.displaySmall,
      headlineMedium: textStyles.headline,
      headlineSmall: textStyles.headline,
      titleLarge: textStyles.title,
      titleMedium: textStyles.titleSmall,
      titleSmall: textStyles.label,
      bodyLarge: textStyles.body,
      bodyMedium: textStyles.body,
      bodySmall: textStyles.bodySmall,
      labelLarge: textStyles.button,
      labelMedium: textStyles.label,
      labelSmall: textStyles.caption,
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
      textStyle: WidgetStatePropertyAll(textStyles.button),
      backgroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.disabled)
              ? colors.surfaceElevated
              : colors.primary),
      foregroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.disabled)
              ? colors.textSecondary
              : colors.onPrimary),
      overlayColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.pressed)
              ? Colors.black.withValues(alpha: 0.08)
              : null),
      splashFactory: NoSplash.splashFactory,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: (isDark ? Brightness.dark : Brightness.light),
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.surfaceElevated,
      cardColor: colors.surface,
      dividerColor: colors.divider,
      disabledColor: colors.textTertiary,
      hintColor: colors.textTertiary,
      // No ripples — iOS-style highlight only. InkWell still shows a subtle
      // pressed highlight via highlightColor.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: colors.textPrimary.withValues(alpha: 0.05),
      hoverColor: colors.textPrimary.withValues(alpha: 0.03),
      focusColor: colors.primary.withValues(alpha: 0.14),
      textTheme: textTheme,
      iconTheme: IconThemeData(color: colors.textPrimary, size: 22),
      primaryIconTheme: IconThemeData(color: colors.onPrimary, size: 22),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: (isDark ? Brightness.dark : Brightness.light),
        primaryColor: colors.primary,
        scaffoldBackgroundColor: colors.background,
        barBackgroundColor: colors.surface,
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: textStyles.title,
        iconTheme: IconThemeData(color: colors.textPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: colors.textPrimary, size: 22),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: (isDark ? Brightness.dark : Brightness.light),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: _inputBorder(colors.borderStrong),
        enabledBorder: _inputBorder(colors.borderStrong),
        disabledBorder: _inputBorder(colors.border),
        focusedBorder: _inputBorder(colors.primary, 1.5),
        errorBorder: _inputBorder(colors.danger.withValues(alpha: 0.75)),
        focusedErrorBorder: _inputBorder(colors.danger, 1.5),
        hintStyle: textStyles.body.copyWith(color: colors.textTertiary),
        labelStyle: textStyles.body.copyWith(color: colors.textSecondary),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          final color = states.contains(WidgetState.error)
              ? colors.danger
              : states.contains(WidgetState.focused)
                  ? colors.primary
                  : colors.textSecondary;
          return textStyles.label.copyWith(color: color);
        }),
        helperStyle: textStyles.caption,
        errorStyle: textStyles.caption.copyWith(color: colors.danger),
        // Mongolian validation copy runs long; don't cut it to one line.
        helperMaxLines: 2,
        errorMaxLines: 2,
        prefixStyle: textStyles.body.copyWith(color: colors.textSecondary),
        suffixStyle: textStyles.body.copyWith(color: colors.textSecondary),
        counterStyle: textStyles.caption,
        prefixIconColor: _inputIconColor(colors),
        suffixIconColor: _inputIconColor(colors),
        iconColor: colors.textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          disabledForegroundColor: colors.textTertiary,
          backgroundColor: colors.surfaceElevated,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: textStyles.button,
          shape: buttonShape,
          side: BorderSide(color: colors.borderStrong),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          disabledForegroundColor: colors.textTertiary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: textStyles.label.copyWith(fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.brSm),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textPrimary,
          disabledForegroundColor: colors.textTertiary,
          minimumSize: const Size(44, 44),
          highlightColor: colors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.brLg,
          side: BorderSide(color: colors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: textStyles.bodyStrong,
        actionTextColor: colors.primary,
        closeIconColor: colors.textSecondary,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.borderStrong),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: colors.scrim,
        dragHandleColor: colors.handle,
        dragHandleSize: const Size(40, 4),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        barrierColor: colors.scrim,
        titleTextStyle: textStyles.title,
        contentTextStyle: textStyles.body.copyWith(color: colors.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.border),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) {
            // Keep a disabled-but-checked box readable (dark check on grey).
            return s.contains(WidgetState.selected)
                ? colors.textTertiary
                : Colors.transparent;
          }
          if (s.contains(WidgetState.selected)) return colors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(colors.onPrimary),
        side: WidgetStateBorderSide.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? BorderSide(color: colors.primary, width: 1.5)
                : BorderSide(color: colors.textSecondary, width: 1.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? colors.primary
                : colors.textSecondary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? colors.onPrimary
                : colors.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? colors.primary
                : colors.surfaceElevated),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? Colors.transparent
                : colors.borderStrong),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceElevated,
        selectedColor: colors.primary.withValues(alpha: 0.16),
        disabledColor: colors.surface,
        checkmarkColor: colors.primary,
        // Selected chips (e.g. gender picker) read gold, not just tinted.
        labelStyle: textStyles.label.copyWith(
          color: WidgetStateColor.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return colors.textTertiary;
            if (s.contains(WidgetState.selected)) return colors.primary;
            return colors.textPrimary;
          }),
        ),
        secondaryLabelStyle: textStyles.label.copyWith(color: colors.primary),
        side: WidgetStateBorderSide.resolveWith((s) => BorderSide(
              color: s.contains(WidgetState.selected)
                  ? colors.primary.withValues(alpha: 0.55)
                  : colors.border,
            )),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        iconTheme: IconThemeData(color: colors.textSecondary, size: 16),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.border),
        ),
        headerBackgroundColor: colors.surface,
        headerForegroundColor: colors.textPrimary,
        headerHeadlineStyle: textStyles.headline,
        headerHelpStyle: textStyles.label.copyWith(color: colors.textSecondary),
        weekdayStyle: textStyles.caption,
        dayStyle: textStyles.label,
        dividerColor: colors.divider,
        subHeaderForegroundColor: colors.textSecondary,
        dayForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return colors.onPrimary;
          if (s.contains(WidgetState.disabled)) {
            return colors.textTertiary.withValues(alpha: 0.5);
          }
          return colors.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? colors.primary
                : Colors.transparent),
        dayOverlayColor: WidgetStatePropertyAll(
          colors.primary.withValues(alpha: 0.12),
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? colors.onPrimary
                : colors.primary),
        todayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? colors.primary
                : Colors.transparent),
        todayBorder: BorderSide(color: colors.primary),
        yearStyle: textStyles.label,
        yearForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return colors.onPrimary;
          if (s.contains(WidgetState.disabled)) {
            return colors.textTertiary.withValues(alpha: 0.5);
          }
          return colors.textPrimary;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? colors.primary
                : Colors.transparent),
        yearOverlayColor: WidgetStatePropertyAll(
          colors.primary.withValues(alpha: 0.12),
        ),
        confirmButtonStyle:
            TextButton.styleFrom(foregroundColor: colors.primary),
        cancelButtonStyle:
            TextButton.styleFrom(foregroundColor: colors.textSecondary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.textPrimary.withValues(alpha: 0.10),
        circularTrackColor: Colors.transparent,
        refreshBackgroundColor: colors.surfaceElevated,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.32),
        selectionHandleColor: colors.primary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        titleTextStyle: textStyles.bodyStrong,
        subtitleTextStyle: textStyles.caption,
        leadingAndTrailingTextStyle: textStyles.body,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
        horizontalTitleGap: 12,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: colors.primary.withValues(alpha: 0.16),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? textStyles.caption.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  )
                : textStyles.caption),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.textSecondary,
            )),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.textSecondary,
        indicatorColor: colors.primary,
        dividerColor: Colors.transparent,
        labelStyle: textStyles.label,
        unselectedLabelStyle: textStyles.label,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: textStyles.body,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.brMd,
          side: BorderSide(color: colors.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceHighlight,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: textStyles.caption.copyWith(color: colors.textPrimary),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          colors.textPrimary.withValues(alpha: 0.2),
        ),
        radius: const Radius.circular(8),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: colors.danger,
        textColor: colors.onPrimary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        splashColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.brLg),
        extendedTextStyle: textStyles.button,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.textPrimary.withValues(alpha: 0.12),
        secondaryActiveTrackColor: colors.primary.withValues(alpha: 0.4),
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.12),
        activeTickMarkColor: colors.onPrimary.withValues(alpha: 0.4),
        inactiveTickMarkColor: colors.textPrimary.withValues(alpha: 0.3),
        disabledActiveTrackColor: colors.textTertiary,
        disabledInactiveTrackColor: colors.textPrimary.withValues(alpha: 0.08),
        disabledThumbColor: colors.textTertiary,
        valueIndicatorColor: colors.surfaceHighlight,
        valueIndicatorTextStyle: textStyles.label,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppLayout.minTapTarget, AppLayout.minTapTarget),
          ),
          textStyle: WidgetStatePropertyAll(textStyles.label),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return colors.textTertiary;
            if (s.contains(WidgetState.selected)) return colors.onPrimary;
            return colors.textPrimary;
          }),
          iconColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? colors.onPrimary
                  : colors.textSecondary),
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.borderStrong),
          ),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textSecondary,
        showUnselectedLabels: true,
        selectedLabelStyle:
            textStyles.caption.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textStyles.caption,
      ),
      menuTheme: MenuThemeData(style: _menuStyle(colors)),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: _menuStyle(colors),
        textStyle: textStyles.body,
      ),
    );
  }
}
