import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Custom-painted gold coin — the app's motif ("Uziy" / зоос = coin).
///
/// Gold rim + radial-lit face + engraved inner ring + specular highlight.
/// At [size] >= 20 a small '₮' glyph is engraved in the center.
/// Decorative: no semantics.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CoinPainter(showGlyph: size >= 20)),
    );
  }
}

class _CoinPainter extends CustomPainter {
  _CoinPainter({required this.showGlyph});

  final bool showGlyph;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    if (r <= 0) return;
    final c = size.center(Offset.zero);

    // Contact shadow so the coin separates from gold backgrounds.
    canvas.drawCircle(
      c + Offset(0, r * 0.10),
      r * 0.96,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.14),
    );

    // Rim.
    final outer = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryLight,
            AppColors.primaryDeep,
            AppColors.primaryInk,
          ],
          stops: [0.0, 0.6, 1.0],
        ).createShader(outer),
    );

    // Face.
    final faceR = r * 0.84;
    canvas.drawCircle(
      c,
      faceR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [
            AppColors.primaryLight,
            AppColors.primary,
            AppColors.primaryDeep,
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: faceR)),
    );

    // Engraved inner ring.
    canvas.drawCircle(
      c,
      r * 0.64,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, r * 0.07)
        ..color = AppColors.primaryInk.withValues(alpha: 0.32),
    );

    // Specular highlight arc (top-left).
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.74),
      math.pi * 1.05,
      math.pi * 0.42,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.8, r * 0.09)
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    if (showGlyph) {
      final tp = TextPainter(
        text: TextSpan(
          text: tugrikSymbol,
          style: TextStyle(
            fontSize: r * 0.95,
            height: 1.0,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryInk.withValues(alpha: 0.85),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(_CoinPainter oldDelegate) =>
      oldDelegate.showGlyph != showGlyph;
}

enum RewardChipSize { small, medium, large }

/// Gold pill with a coin and the signed reward: `[coin] +700 ₮`.
class RewardChip extends StatelessWidget {
  const RewardChip({
    super.key,
    required this.amount,
    this.size = RewardChipSize.medium,
    this.glow = false,
  });

  final num amount;
  final RewardChipSize size;

  /// Adds a soft gold glow (use on dark imagery / hero moments).
  final bool glow;

  /// Upper bound for OS text scaling inside the fixed-height pill.
  static const double maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
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
          gradient: AppGradients.gold,
          borderRadius: AppRadii.brPill,
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          boxShadow: glow
              ? AppShadows.glow(
                  AppColors.primary,
                  strength: 0.9,
                  blur: height * 0.6,
                  offset: Offset(0, height * 0.15),
                )
              : null,
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
                  color: AppColors.onPrimary,
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
