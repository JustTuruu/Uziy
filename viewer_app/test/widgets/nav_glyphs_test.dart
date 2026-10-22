import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/nav_glyphs.dart';

/// Paints [painter] on a [size] square and returns the RGBA bytes.
Future<List<int>> _pixels(NavGlyphPainter painter, {double size = 48}) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Size.square(size));
  final image =
      await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List().toList();
}

int _inked(List<int> rgba) {
  var n = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] > 128) n++;
  }
  return n;
}

/// Whether the pixel at grid point [p] (in 24ths) is painted on a [size] box.
bool _inkAt(List<int> rgba, Offset p, {double size = 48}) {
  final s = size / NavGlyphPainter.grid;
  final x = (p.dx * s).round(), y = (p.dy * s).round();
  return rgba[(y * size.toInt() + x) * 4 + 3] > 128;
}

void main() {
  for (final kind in NavGlyphKind.values) {
    group('$kind', () {
      testWidgets('outline and filled render at the requested size',
          (tester) async {
        for (final filled in [false, true]) {
          await tester.pumpWidget(MaterialApp(
            home: Center(
              child: NavGlyph(
                  kind: kind, color: Colors.black, filled: filled, size: 32),
            ),
          ));
          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(NavGlyph)), const Size(32, 32));
        }
      });

      test('filled is heavier than the outline (the active tab reads solid)',
          () async {
        final outline = await _pixels(
            NavGlyphPainter(kind: kind, color: Colors.black, filled: false));
        final solid = await _pixels(
            NavGlyphPainter(kind: kind, color: Colors.black, filled: true));
        expect(_inked(solid), greaterThan(_inked(outline) * 1.5));
      });
    });
  }

  test('home: the play door is ink on the outline and a hole when filled',
      () async {
    const door = Offset(12, 14.3);
    final outline = await _pixels(const NavGlyphPainter(
        kind: NavGlyphKind.home, color: Colors.black, filled: false));
    final solid = await _pixels(const NavGlyphPainter(
        kind: NavGlyphKind.home, color: Colors.black, filled: true));
    expect(_inkAt(outline, door), isTrue);
    expect(_inkAt(solid, door), isFalse);
    // The body around the door is solid when filled.
    expect(_inkAt(solid, const Offset(7, 18)), isTrue);
  });

  test('wallet: the coin is ink on the outline and a hole when filled',
      () async {
    final outline = await _pixels(const NavGlyphPainter(
        kind: NavGlyphKind.wallet, color: Colors.black, filled: false));
    final solid = await _pixels(const NavGlyphPainter(
        kind: NavGlyphKind.wallet, color: Colors.black, filled: true));
    expect(_inkAt(outline, NavGlyphPainter.coinCentre), isTrue);
    expect(_inkAt(solid, NavGlyphPainter.coinCentre), isFalse);
  });

  test('painter repaints only when kind, colour or fill changes', () {
    const a = NavGlyphPainter(
        kind: NavGlyphKind.home, color: Colors.white, filled: false);
    expect(
        a.shouldRepaint(const NavGlyphPainter(
            kind: NavGlyphKind.home, color: Colors.white, filled: false)),
        isFalse);
    expect(
        a.shouldRepaint(const NavGlyphPainter(
            kind: NavGlyphKind.wallet, color: Colors.white, filled: false)),
        isTrue);
    expect(
        a.shouldRepaint(const NavGlyphPainter(
            kind: NavGlyphKind.home, color: Colors.white, filled: true)),
        isTrue);
    expect(
        a.shouldRepaint(const NavGlyphPainter(
            kind: NavGlyphKind.home, color: Colors.black, filled: false)),
        isTrue);
  });

  testWidgets('the builders fill only the selected tab', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Column(children: [
        NavGlyph.home(Colors.black, true),
        NavGlyph.wallet(Colors.black, false),
      ]),
    ));
    final glyphs = tester.widgetList<NavGlyph>(find.byType(NavGlyph)).toList();
    expect(glyphs[0].kind, NavGlyphKind.home);
    expect(glyphs[0].filled, isTrue);
    expect(glyphs[1].kind, NavGlyphKind.wallet);
    expect(glyphs[1].filled, isFalse);
  });
}
