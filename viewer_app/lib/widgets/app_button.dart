import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'fill_width.dart';
import 'pressable.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { normal, small }

/// The app's CTA button.
///
/// * primary — gold gradient, gold glow, near-black label.
/// * secondary — elevated surface with hairline border.
/// * ghost — no background, gold label (text-link style).
/// * danger — translucent red, light-red label (AA).
///
/// Disabled (`onPressed == null`) looks clearly muted: surfaceElevated
/// background, textSecondary label, no glow. The disabled <-> enabled change
/// animates (nice for gates such as "watch the full video first").
/// While [loading] the variant look is kept, a spinner replaces the label and
/// taps are ignored.
///
/// Height 54 (small: 44, still a full 44pt tap target), radius 16 (small:
/// 14). With [expand] (default) it fills the available width when the width
/// is bounded. Where the width is unbounded (a Row child without Expanded, a
/// horizontal list) it hugs its label and does not throw. Inside a Row, wrap
/// it in Expanded to share the width.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.size = AppButtonSize.normal,
    this.haptic = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final AppButtonSize size;

  /// Selection-click haptic on tap.
  final bool haptic;

  /// Overrides the screen-reader label (defaults to [label]).
  final String? semanticLabel;

  static LinearGradient _solid(Color c) => LinearGradient(colors: [c, c]);

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final small = size == AppButtonSize.small;
    final height = small ? AppLayout.minTapTarget : 54.0;
    final radius = BorderRadius.circular(small ? 14 : AppRadii.md);

    final Gradient gradient;
    final Color fg;
    Border? border;
    List<BoxShadow> shadows = const [];

    if (disabled) {
      final ghost = variant == AppButtonVariant.ghost;
      gradient = _solid(ghost ? Colors.transparent : AppColors.surfaceElevated);
      fg = ghost ? AppColors.textTertiary : AppColors.textSecondary;
      border = ghost ? null : Border.all(color: AppColors.border);
    } else {
      switch (variant) {
        case AppButtonVariant.primary:
          gradient = AppGradients.gold;
          fg = AppColors.onPrimary;
          shadows = AppShadows.glow(
            AppColors.primary,
            strength: small ? 0.6 : 0.9,
            blur: small ? 14 : 22,
            offset: Offset(0, small ? 4 : 8),
          );
        case AppButtonVariant.secondary:
          gradient = _solid(AppColors.surfaceElevated);
          fg = AppColors.textPrimary;
          border = Border.all(color: AppColors.borderStrong);
        case AppButtonVariant.ghost:
          gradient = _solid(Colors.transparent);
          fg = AppColors.primary;
        case AppButtonVariant.danger:
          gradient = _solid(AppColors.danger.withValues(alpha: 0.12));
          fg = AppColors.dangerLight; // AA on the red tint
          border = Border.all(color: AppColors.danger.withValues(alpha: 0.35));
      }
    }

    final textStyle = (small ? AppTextStyles.label : AppTextStyles.button)
        .copyWith(color: fg, fontWeight: FontWeight.w700);

    final Widget content = loading
        ? SizedBox(
            key: const ValueKey('app-button-loading'),
            width: small ? 18 : 22,
            height: small ? 18 : 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          )
        : Row(
            key: const ValueKey('app-button-label'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: small ? 18 : 20, color: fg),
                SizedBox(width: small ? 6 : 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              ),
            ],
          );

    final box = AnimatedContainer(
      duration: AppMotion.duration(context, AppDurations.normal),
      curve: AppMotion.standard,
      height: height,
      constraints: BoxConstraints(minWidth: height),
      padding: EdgeInsets.symmetric(horizontal: small ? 16 : 22),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        border: border,
        boxShadow: shadows,
      ),
      child: Center(
        widthFactor: expand ? null : 1.0,
        child: AnimatedSwitcher(
          duration: AppMotion.duration(context, AppDurations.fast),
          child: content,
        ),
      ),
    );

    return Pressable(
      onTap: (disabled || loading) ? null : onPressed,
      haptic: haptic,
      scale: small ? 0.96 : 0.97,
      semanticLabel: semanticLabel ?? label,
      excludeSemantics: true,
      // FillWidth, not `width: double.infinity`, so a stray AppButton in a
      // Row hugs its content instead of crashing layout.
      child: expand ? FillWidth(child: box) : box,
    );
  }
}

enum AppIconButtonVariant {
  /// Elevated surface circle with hairline border.
  surface,

  /// Translucent black circle — for use over video / imagery.
  glass,

  /// Icon only, no background.
  plain,
}

/// Circular icon-only button with a guaranteed 44pt tap target and a
/// required screen-reader label.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.variant = AppIconButtonVariant.surface,
    this.size = 44,
    this.iconSize = 20,
    this.color,
    this.haptic = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final AppIconButtonVariant variant;

  /// Visual diameter. The tap target is never smaller than 44.
  final double size;
  final double iconSize;

  /// Icon color override (defaults to textPrimary / white on glass).
  final Color? color;
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final Color bg;
    final Border? border;
    switch (variant) {
      case AppIconButtonVariant.surface:
        bg = AppColors.surfaceElevated;
        border = Border.all(color: AppColors.border);
      case AppIconButtonVariant.glass:
        bg = Colors.black.withValues(alpha: 0.45);
        border = Border.all(color: Colors.white.withValues(alpha: 0.12));
      case AppIconButtonVariant.plain:
        bg = Colors.transparent;
        border = null;
    }
    final fg = disabled
        ? AppColors.textTertiary
        : (color ??
            (variant == AppIconButtonVariant.glass
                ? Colors.white
                : AppColors.textPrimary));
    final target =
        size < AppLayout.minTapTarget ? AppLayout.minTapTarget : size;

    return Pressable(
      onTap: onPressed,
      haptic: haptic,
      scale: 0.92,
      semanticLabel: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: target,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: border,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: iconSize, color: fg),
          ),
        ),
      ),
    );
  }
}
