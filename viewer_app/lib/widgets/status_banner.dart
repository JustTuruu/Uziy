import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';

enum BannerTone { error, info, success, warning }

/// Inline status message (errors, notices, confirmations).
///
/// Tinted translucent panel with a tone-colored icon badge, optional bold
/// [title], the [message] in readable textPrimary, and an optional action
/// (e.g. 'Дахин оролдох' -> retry). Errors are announced as a live region.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.tone = BannerTone.error,
    this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String message;
  final BannerTone tone;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Overrides the tone's default icon.
  final IconData? icon;

  static Color colorFor(BannerTone tone, AppPalette palette) => switch (tone) {
        BannerTone.error => palette.danger,
        BannerTone.info => palette.accent,
        BannerTone.success => palette.success,
        BannerTone.warning => palette.warning,
      };

  /// Text tint for the title / action: a lighter shade of [colorFor] so it
  /// stays WCAG AA on the tinted panel.
  static Color textColorFor(BannerTone tone, AppPalette palette) =>
      switch (tone) {
        BannerTone.error => palette.dangerLight,
        BannerTone.info => palette.accentLight,
        BannerTone.success => palette.successLight,
        BannerTone.warning => palette.warning,
      };

  static IconData iconFor(BannerTone tone) => switch (tone) {
        BannerTone.error => Icons.error_outline_rounded,
        BannerTone.info => Icons.info_outline_rounded,
        BannerTone.success => Icons.check_circle_outline_rounded,
        BannerTone.warning => Icons.warning_amber_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = colorFor(tone, context.colors);
    final ink = textColorFor(tone, context.colors);
    final hasAction = actionLabel != null && onAction != null;

    return Semantics(
      liveRegion: tone == BannerTone.error,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: AppRadii.brMd,
          border: Border.all(color: c.withValues(alpha: 0.30)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon ?? iconFor(tone), size: 18, color: c),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: context.textStyles.label.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      message,
                      style: context.textStyles.bodySmall
                          .copyWith(color: context.colors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            if (hasAction)
              Pressable(
                onTap: onAction,
                haptic: true,
                scale: 0.94,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppLayout.minTapTarget,
                    minWidth: AppLayout.minTapTarget,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        actionLabel!,
                        style: context.textStyles.label.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
