import 'package:flutter/material.dart';

import '../../widgets/ui.dart';

/// The sign-in page's paper: a few oversized, almost invisible sage curves —
/// one soft swell in the top-right corner and layered folds along the
/// bottom, like sheets of tinted paper. Pure vector (no image), drawn in
/// the brand green at a few percent opacity, so it scales to any phone and
/// never competes with the form. Decorative only: no taps, no semantics.
class LoginBackdrop extends StatelessWidget {
  const LoginBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: LoginBackdropPainter(
            tint: context.colors.primary,
            dark: context.colors.isDark,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Paints [LoginBackdrop]. Every shape is placed in fractions of the size,
/// so short and tall phones get the same composition.
class LoginBackdropPainter extends CustomPainter {
  const LoginBackdropPainter({required this.tint, required this.dark});

  final Color tint;
  final bool dark;

  /// Opacities of the layers, faintest first. The dark theme's mint tint is
  /// brighter, so it uses less.
  List<double> get _alphas =>
      dark ? const [0.02, 0.03, 0.045] : const [0.028, 0.045, 0.06];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final a = _alphas;
    Paint fill(double alpha) => Paint()..color = tint.withValues(alpha: alpha);

    // Top right: two swells hugging the corner, kept clear of the title
    // (they reach about a quarter down and half across).
    canvas.drawCircle(Offset(w * 1.08, -h * 0.02), w * 0.58, fill(a[0]));
    canvas.drawCircle(Offset(w * 1.18, h * 0.12), w * 0.42, fill(a[0]));

    // Bottom left: a fold rising from the left edge.
    final left = Path()
      ..moveTo(0, h * 0.86)
      ..cubicTo(w * 0.38, h * 0.86, w * 0.62, h * 0.93, w * 0.82, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(left, fill(a[1]));

    // Bottom right: a second sheet sweeping in from the right, over it.
    final right = Path()
      ..moveTo(w, h * 0.90)
      ..cubicTo(w * 0.70, h * 0.88, w * 0.40, h * 0.94, w * 0.18, h)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(right, fill(a[2]));
  }

  @override
  bool shouldRepaint(LoginBackdropPainter old) =>
      old.tint != tint || old.dark != dark;
}
