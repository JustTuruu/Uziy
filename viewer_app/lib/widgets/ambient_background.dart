import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AmbientVariant {
  /// Warm gold glow top-right, cool blue low-left, faint violet bottom-right.
  standard,

  /// Stronger gold (splash, auth, reward moments).
  gold,

  /// Barely-there glows for dense content screens.
  subtle,
}

/// Near-black background with soft radial glows for depth.
///
/// Painted with plain radial gradients (no BackdropFilter blur), sized to
/// [child], and never intercepts gestures. Typical use: wrap a Scaffold whose
/// `backgroundColor` is `Colors.transparent`, or use as a Scaffold body.
///
/// [child] sits behind its own repaint boundary, so animations inside the
/// screen (count-ups, shimmers, list entrances) never re-run the full-screen
/// gradient paint.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.variant = AmbientVariant.standard,
  });

  final Widget child;
  final AmbientVariant variant;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AmbientPainter(variant),
      isComplex: true,
      child: RepaintBoundary(child: child),
    );
  }
}

class _Glow {
  const _Glow(this.center, this.radius, this.color, this.alpha);

  /// Center as a fraction of (width, height).
  final Offset center;

  /// Radius as a fraction of the width.
  final double radius;
  final Color color;
  final double alpha;
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.variant);

  final AmbientVariant variant;

  List<_Glow> get _glows => switch (variant) {
        AmbientVariant.standard => const [
            _Glow(Offset(0.92, -0.04), 0.95, AppColors.primary, 0.11),
            _Glow(Offset(-0.12, 0.72), 0.85, AppColors.accent, 0.09),
            _Glow(Offset(1.05, 1.02), 0.75, AppColors.violet, 0.07),
          ],
        AmbientVariant.gold => const [
            _Glow(Offset(0.5, 0.18), 1.05, AppColors.primary, 0.17),
            _Glow(Offset(0.95, -0.05), 0.7, AppColors.primaryDeep, 0.10),
            _Glow(Offset(-0.1, 0.95), 0.8, AppColors.violet, 0.07),
          ],
        AmbientVariant.subtle => const [
            _Glow(Offset(0.92, -0.04), 0.9, AppColors.primary, 0.06),
            _Glow(Offset(-0.12, 0.8), 0.8, AppColors.accent, 0.05),
          ],
      };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.background);
    if (size.isEmpty) return;
    for (final g in _glows) {
      final center =
          Offset(g.center.dx * size.width, g.center.dy * size.height);
      final radius = g.radius * size.width;
      final glowRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              g.color.withValues(alpha: g.alpha),
              g.color.withValues(alpha: g.alpha * 0.45),
              g.color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(glowRect),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      oldDelegate.variant != variant;

  // Purely decorative — never claim hits.
  @override
  bool? hitTest(Offset position) => false;
}
