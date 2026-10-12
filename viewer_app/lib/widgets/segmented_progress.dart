import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Step progress as [total] rounded segments (e.g. survey questions).
///
/// Segments before [current] are completed ([completedColor], default gold),
/// the [current] one is active (gold + soft glow) and filled up to
/// [currentFill] of its width, later ones are an empty dim track.
/// [current] is the 0-based index of the active step; values past the end
/// mark everything complete. Fill and color changes animate.
class SegmentedProgress extends StatelessWidget {
  const SegmentedProgress({
    super.key,
    required this.total,
    required this.current,
    this.completedColor,
    this.height = 4,
    this.gap = 6,
    this.currentFill = 1,
  }) : assert(currentFill >= 0 && currentFill <= 1);

  /// Opacity of the white track under the fill.
  static const double trackOpacity = 0.12;

  final int total;
  final int current;
  final Color? completedColor;
  final double height;
  final double gap;

  /// How much of the active segment is filled, 0..1. Below 1 it reads as
  /// "this step is started, not finished yet".
  final double currentFill;

  /// Filled share of segment [index]: done = 1, active = [currentFill],
  /// upcoming = 0.
  double fillOf(int index) => index < current
      ? 1
      : index == current
          ? currentFill
          : 0;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: trackOpacity),
                    borderRadius: AppRadii.brPill,
                  ),
                  child: AnimatedFractionallySizedBox(
                    duration: duration,
                    curve: AppMotion.standard,
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: fillOf(i),
                    child: AnimatedContainer(
                      duration: duration,
                      curve: AppMotion.standard,
                      decoration: BoxDecoration(
                        color: i < current ? done : AppColors.primary,
                        borderRadius: AppRadii.brPill,
                        boxShadow: i == current && currentFill > 0
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
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
