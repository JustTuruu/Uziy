import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Step progress as [total] rounded segments (e.g. survey questions).
///
/// Segments before [current] are completed ([completedColor], default gold),
/// the [current] one is active (gold + soft glow), later ones are dim.
/// [current] is the 0-based index of the active step; values past the end
/// mark everything complete. Color changes animate.
class SegmentedProgress extends StatelessWidget {
  const SegmentedProgress({
    super.key,
    required this.total,
    required this.current,
    this.completedColor,
    this.height = 4,
    this.gap = 6,
  });

  final int total;
  final int current;
  final Color? completedColor;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return SizedBox(height: height);
    final done = completedColor ?? AppColors.primary;
    final duration = AppMotion.duration(context, AppDurations.medium);
    final step = (current + 1).clamp(0, total);

    return Semantics(
      label: 'Явц: $step/$total',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                child: AnimatedContainer(
                  duration: duration,
                  curve: AppMotion.standard,
                  decoration: BoxDecoration(
                    color: i < current
                        ? done
                        : i == current
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.12),
                    borderRadius: AppRadii.brPill,
                    boxShadow: i == current
                        ? AppShadows.glow(
                            AppColors.primary,
                            strength: 0.8,
                            blur: 8,
                            offset: Offset.zero,
                          )
                        : const [],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
