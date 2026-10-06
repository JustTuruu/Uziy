import 'package:flutter/material.dart';

/// Instagram-Reels-style glyph: a rounded square with a slanted "clapper"
/// line across the top and a play triangle.
///
/// Outline when [filled] is false; solid with the details cut out when true.
class ReelsIcon extends StatelessWidget {
  const ReelsIcon({
    super.key,
    required this.color,
    this.filled = false,
    this.size = 24,
  });

  final Color color;
  final bool filled;
  final double size;

  /// Nav-bar glyph builder (see `AppNavItem.glyphBuilder`).
  static Widget glyph(Color color, bool selected) =>
      ReelsIcon(color: color, filled: selected);

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: ReelsIconPainter(color: color, filled: filled)),
    );
  }
}

class ReelsIconPainter extends CustomPainter {
  const ReelsIconPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.085;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.1, s * 0.1, s * 0.8, s * 0.8),
      Radius.circular(s * 0.22),
    );
    // Horizontal line under the "clapper" header, and two slanted ticks.
    final header = Path()
      ..moveTo(s * 0.1, s * 0.34)
      ..lineTo(s * 0.9, s * 0.34);
    final ticks = Path()
      ..moveTo(s * 0.36, s * 0.1)
      ..lineTo(s * 0.46, s * 0.34)
      ..moveTo(s * 0.62, s * 0.1)
      ..lineTo(s * 0.72, s * 0.34);
    final play = Path()
      ..moveTo(s * 0.43, s * 0.5)
      ..lineTo(s * 0.43, s * 0.76)
      ..lineTo(s * 0.65, s * 0.63)
      ..close();

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (!filled) {
      line.color = color;
      canvas
        ..drawRRect(box, line)
        ..drawPath(header, line)
        ..drawPath(ticks, line)
        ..drawPath(play, line);
      return;
    }

    // Solid body, then punch the details out of it.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(box, Paint()..color = color);
    line.blendMode = BlendMode.clear;
    canvas
      ..drawPath(header, line)
      ..drawPath(ticks, line)
      ..drawPath(play, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ReelsIconPainter old) =>
      old.color != color || old.filled != filled;
}
