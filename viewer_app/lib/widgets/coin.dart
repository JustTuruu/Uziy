import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

/// The app's coin ("Uziy" / зоос = coin): the Uziy mark struck on a flat
/// brand-green disc, with a thin inner ring at readable sizes.
///
/// Flat on purpose (owner, 2026-10-14: the old lit gold coin with a '₮' did
/// not belong to the calm green UI). The disc is the action colour of the
/// theme, the mark is the colour that sits on it, so it works in light and
/// dark. Decorative: no semantics.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});

  final double size;

  /// Below this the inner ring is left out (it would only blur the mark).
  static const double ringMinSize = 20;

  /// Share of the diameter the mark takes.
  static const double markScale = 0.52;

  static const String markAssetPath = 'assets/logo_mark.png';

  @override
  Widget build(BuildContext context) {
    final disc = context.colors.primary;
    final ink = context.colors.onPrimary;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
          child: CustomPaint(
            painter: size >= ringMinSize ? _CoinRingPainter(ink) : null,
            child: Center(
              child: Image.asset(
                markAssetPath,
                width: size * markScale,
                height: size * markScale,
                fit: BoxFit.contain,
                color: ink,
                // Never fails the coin: a missing asset leaves the plain
                // disc rather than an error box.
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The coin's thin inner ring, like the edge of a struck coin.
class _CoinRingPainter extends CustomPainter {
  const _CoinRingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      size.center(Offset.zero),
      r * 0.80,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.06)
        ..color = color.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_CoinRingPainter old) => old.color != color;
}

enum RewardChipSize { small, medium, large }

/// Flat gold pill with a coin and the signed reward: `[coin] +700 ₮`.
/// The reward of one campaign: the coin and '+700 ₮' on a soft wash of the
/// action colour, in the action colour's ink. (Owner, 2026-10-21: the flat
/// gold pill was too loud; green on green belongs to the Meadow palette and
/// reads in light and dark alike.) Flat: no glow.
class RewardChip extends StatelessWidget {
  const RewardChip({
    super.key,
    required this.amount,
    this.size = RewardChipSize.medium,
  });

  final num amount;
  final RewardChipSize size;

  /// Upper bound for OS text scaling inside the fixed-height pill.
  static const double maxTextScale = 1.3;

  /// The pill's fill: the action colour washed over the card surface.
  static Color fillIn(AppPalette c) => c.actionWash;

  /// The amount's ink.
  static Color inkIn(AppPalette c) => c.primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (double height, double coin, double font, double gap) =
        switch (size) {
      RewardChipSize.small => (26.0, 16.0, 12.5, 5.0),
      RewardChipSize.medium => (32.0, 21.0, 14.5, 6.0),
      RewardChipSize.large => (46.0, 30.0, 21.0, 8.0),
    };
    final label = formatTugrik(amount, withSign: true);

    return Semantics(
      label: 'Урамшуулал $label',
      excludeSemantics: true,
      child: Container(
        height: height,
        padding: EdgeInsets.only(
          left: (height - coin) / 2,
          right: height * 0.42,
        ),
        decoration: BoxDecoration(
          color: fillIn(colors),
          borderRadius: AppRadii.brPill,
          border: Border.all(color: colors.actionLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoinIcon(size: coin),
            SizedBox(width: gap),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // The pill has a fixed height; cap OS text scaling so the
                // amount never spills out of it.
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: maxTextScale),
                style: TextStyle(
                  fontSize: font,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: inkIn(colors),
                  fontFeatures: AppTextStyles.tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
