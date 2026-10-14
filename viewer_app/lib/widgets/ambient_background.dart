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
      painter: _AmbientPainter(variant, context.colors),
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
  _AmbientPainter(this.variant, this.colors);
  final AppPalette colors;

  final AmbientVariant variant;

  List<_Glow> get _glows => switch (variant) {
        AmbientVariant.standard => [
            _Glow(const Offset(0.92, -0.04), 0.95, colors.primary, 0.025),
            _Glow(const Offset(-0.12, 0.72), 0.85, colors.accent, 0.015),
            _Glow(const Offset(1.05, 1.02), 0.75, colors.violet, 0.01),
          ],
        AmbientVariant.gold => [
            _Glow(const Offset(0.5, 0.18), 1.05, colors.primary, 0.045),
            _Glow(const Offset(0.95, -0.01), 0.7, colors.primaryDeep, 0.02),
            _Glow(const Offset(-0.1, 0.95), 0.8, colors.violet, 0.01),
          ],
        AmbientVariant.subtle => [
            _Glow(const Offset(0.92, -0.04), 0.9, colors.primary, 0.015),
            _Glow(const Offset(-0.12, 0.8), 0.8, colors.accent, 0.01),
          ],
      };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = colors.background);
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
      oldDelegate.variant != variant ||
      oldDelegate.colors.isDark != colors.isDark;

  // Purely decorative — never claim hits.
  @override
  bool? hitTest(Offset position) => false;
}
