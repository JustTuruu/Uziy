import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';

/// Layered surface card: surface fill, hairline border, lit top edge.
///
/// Pass [gradient] to replace the flat fill (e.g. `AppGradients.gold` for the
/// wallet card). When [onTap] is set the card gets the press-scale
/// interaction (see [Pressable]).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.gradient,
    this.color,
    this.borderColor,
    this.radius = AppRadii.lg,
    this.highlight = true,
    this.shadows,
    this.semanticLabel,
    this.haptic = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Replaces [color] when set.
  final Gradient? gradient;

  /// Flat fill (defaults to [AppColors.surface]).
  final Color? color;

  /// Hairline border color (defaults to [AppColors.border]).
  /// Pass `Colors.transparent` for no visible border.
  final Color? borderColor;
  final double radius;

  /// Paint the subtle top sheen.
  final bool highlight;
  final List<BoxShadow>? shadows;

  /// Screen-reader label when tappable.
  final String? semanticLabel;
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    // Fill + shadow behind; content clipped with a cheap RRect clip (not the
    // ClipPath a clipped Container would use); the hairline is painted in
    // the foreground so full-bleed content (e.g. CampaignArt with zero
    // padding) never hides it.
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: br,
        boxShadow: shadows,
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: br,
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: br,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: highlight ? AppGradients.sheen : null,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );

    if (onTap != null) {
      card = Pressable(
        onTap: onTap,
        haptic: haptic,
        scale: 0.98,
        semanticLabel: semanticLabel,
        child: card,
      );
    }
    return card;
  }
}
