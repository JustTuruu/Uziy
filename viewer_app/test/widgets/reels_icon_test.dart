import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/reels_icon.dart';

void main() {
  testWidgets('outline and filled variants render at the requested size',
      (tester) async {
    for (final filled in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ReelsIcon(color: Colors.white, filled: filled, size: 32),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ReelsIcon)), const Size(32, 32));
    }
  });

  test('painter repaints only when colour or fill changes', () {
    const a = ReelsIconPainter(color: Colors.white, filled: false);
    expect(a.shouldRepaint(const ReelsIconPainter(color: Colors.white, filled: false)), isFalse);
    expect(a.shouldRepaint(const ReelsIconPainter(color: Colors.white, filled: true)), isTrue);
    expect(a.shouldRepaint(const ReelsIconPainter(color: Colors.black, filled: false)), isTrue);
  });

  testWidgets('glyph() builds a filled icon only when selected', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Column(children: [
        ReelsIcon.glyph(Colors.white, true),
        ReelsIcon.glyph(Colors.white, false),
      ]),
    ));
    final icons = tester.widgetList<ReelsIcon>(find.byType(ReelsIcon)).toList();
    expect(icons.map((i) => i.filled), [true, false]);
  });
}
