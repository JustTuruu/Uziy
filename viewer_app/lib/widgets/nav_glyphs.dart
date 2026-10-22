import 'package:flutter/material.dart';

/// Which bottom-tab glyph to draw.
enum NavGlyphKind { home, wallet }

/// The Нүүр and Хэтэвч tab glyphs (owner, 2026-10-21: nicer than the Reels
/// clapper and the stock wallet), drawn on a 24-unit grid with the same
/// 2-unit rounded stroke as the Material rounded icons beside them.
///
/// * home — a rounded house whose door is a play triangle: the place the
///   videos live.
/// * wallet — a wallet with its clasp, a coin on the clasp: where the
///   rewards land.
///
/// Outline when not [filled]; solid with the details cut out when [filled]
/// (the active tab).
class NavGlyph extends StatelessWidget {
  const NavGlyph({
    super.key,
    required this.kind,
    required this.color,
    this.filled = false,
    this.size = 24,
  });

  final NavGlyphKind kind;
  final Color color;
  final bool filled;
  final double size;

  /// Nav-bar glyph builders (see `AppNavItem.glyphBuilder`).
  static Widget home(Color color, bool selected) =>
      NavGlyph(kind: NavGlyphKind.home, color: color, filled: selected);
  static Widget wallet(Color color, bool selected) =>
      NavGlyph(kind: NavGlyphKind.wallet, color: color, filled: selected);

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: NavGlyphPainter(kind: kind, color: color, filled: filled),
      ),
    );
  }
}

class NavGlyphPainter extends CustomPainter {
  const NavGlyphPainter({
    required this.kind,
    required this.color,
    required this.filled,
  });

  final NavGlyphKind kind;
  final Color color;
  final bool filled;

  /// The design grid: every coordinate below is in 24ths of the box.
  static const double grid = 24;
  static const double stroke = 2;

  /// House outline: a pitched roof over a body with rounded lower corners.
  static Path house() => Path()
    ..moveTo(4.5, 10.2)
    ..lineTo(12, 3.8)
    ..lineTo(19.5, 10.2)
    ..lineTo(19.5, 18)
    ..quadraticBezierTo(19.5, 20.2, 17.3, 20.2)
    ..lineTo(6.7, 20.2)
    ..quadraticBezierTo(4.5, 20.2, 4.5, 18)
    ..close();

  /// The door: a play triangle, optically centred in the body.
  static Path door() => Path()
    ..moveTo(10.4, 11.6)
    ..lineTo(14.8, 14.3)
    ..lineTo(10.4, 17)
    ..close();

  /// Wallet body.
  static RRect walletBody() =>
      RRect.fromLTRBR(3.2, 6.6, 20.8, 19.8, const Radius.circular(3.4));

  /// The card tucked behind the body's top edge.
  static Path walletFlap() => Path()
    ..moveTo(5.6, 6.6)
    ..lineTo(15.2, 3.9)
    ..quadraticBezierTo(16.9, 3.5, 17.2, 5.2)
    ..lineTo(17.5, 6.6);

  /// The clasp on the right edge.
  static RRect walletClasp() =>
      RRect.fromLTRBR(14.2, 10.6, 20.8, 15.8, const Radius.circular(2.6));

  /// The coin on the clasp.
  static const Offset coinCentre = Offset(17.2, 13.2);
  static const double coinRadius = 1.25;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / grid;
    canvas.save();
    canvas.scale(scale);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final solid = Paint()..color = color;
    final cut = Paint()..blendMode = BlendMode.clear;

    switch (kind) {
      case NavGlyphKind.home:
        if (filled) {
          canvas.saveLayer(Offset.zero & const Size(grid, grid), Paint());
          canvas.drawPath(house(), solid);
          canvas.drawPath(house(), line);
          canvas.drawPath(door(), cut);
          canvas.restore();
        } else {
          canvas.drawPath(house(), line);
          canvas.drawPath(door(), solid);
        }
      case NavGlyphKind.wallet:
        canvas.drawPath(walletFlap(), line);
        if (filled) {
          canvas.saveLayer(Offset.zero & const Size(grid, grid), Paint());
          canvas.drawRRect(walletBody(), solid);
          canvas.drawRRect(walletBody(), line);
          canvas.drawRRect(walletClasp().deflate(0.2), cut);
          canvas.drawRRect(walletClasp().deflate(1.4), solid);
          canvas.drawCircle(coinCentre, coinRadius, cut);
          canvas.restore();
        } else {
          canvas.drawRRect(walletBody(), line);
          canvas.drawRRect(walletClasp(), line);
          canvas.drawCircle(coinCentre, coinRadius, solid);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(NavGlyphPainter old) =>
      old.kind != kind || old.color != color || old.filled != filled;
}
