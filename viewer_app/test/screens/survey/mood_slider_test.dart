import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/survey/mood_logic.dart';
import 'package:viewer_app/screens/survey/mood_slider.dart';
import 'package:viewer_app/theme/app_theme.dart';

Future<void> _pump(
  WidgetTester tester, {
  int? selectedIndex,
  ValueChanged<int>? onChanged,
  bool reduceMotion = false,
  List<String> labels = kMoodLabels,
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: MoodSlider(
            labels: labels,
            selectedIndex: selectedIndex,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _thumb => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is MoodThumbPainter,
    );
Finder get _face => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is MoodFacePainter,
    );

double _facePosition(WidgetTester tester) =>
    (tester.widget<CustomPaint>(_face).painter! as MoodFacePainter).position;

void main() {
  testWidgets('starts on Дунд and shows every label', (tester) async {
    await _pump(tester);

    expect(_facePosition(tester), closeTo(kMoodStartPosition, 0.1));
    for (final label in kMoodLabels) {
      expect(find.text(label), findsOneWidget); // slider label
      expect(find.text(label.toUpperCase()), findsOneWidget); // big word
    }
  });

  testWidgets('an untouched slider answers nothing, even after its nudge',
      (tester) async {
    final picked = <int>[];
    await _pump(tester, onChanged: picked.add);
    await tester.pumpAndSettle();

    expect(picked, isEmpty);
    expect(_facePosition(tester), closeTo(kMoodStartPosition, 1e-9));
  });

  testWidgets('dragging the thumb to the right end picks Маш сайн',
      (tester) async {
    final picked = <int>[];
    await _pump(tester, onChanged: picked.add);

    await tester.drag(_thumb, const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(picked, [4]);
    expect(_facePosition(tester), closeTo(1, 1e-9));
  });

  testWidgets('dragging to the left end picks Маш муу', (tester) async {
    final picked = <int>[];
    await _pump(tester, onChanged: picked.add);

    await tester.drag(_thumb, const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(picked, [0]);
    expect(_facePosition(tester), closeTo(0, 1e-9));
  });

  testWidgets('a short drag settles back on the nearest stop', (tester) async {
    final picked = <int>[];
    await _pump(tester, onChanged: picked.add);

    await tester.drag(_thumb, const Offset(20, 0));
    await tester.pumpAndSettle();

    expect(picked, [2]);
    expect(_facePosition(tester), closeTo(0.5, 1e-9));
  });

  testWidgets('the face morphs while the thumb is mid-drag', (tester) async {
    await _pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(_thumb));
    // The first move only gets past the touch slop and starts the drag.
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    final midDrag = _facePosition(tester);
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();

    expect(midDrag, greaterThan(0.5));
    expect(midDrag, lessThan(1));
    expect(_facePosition(tester), greaterThan(midDrag));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('tapping a label jumps to that stop', (tester) async {
    final picked = <int>[];
    await _pump(tester, onChanged: picked.add);

    await tester.tap(find.text('Муу'));
    await tester.pumpAndSettle();

    expect(picked, [1]);
    expect(_facePosition(tester), closeTo(0.25, 1e-9));
  });

  testWidgets('tapping the track jumps to the nearest stop', (tester) async {
    final picked = <int>[];
    await _pump(tester, onChanged: picked.add);
    final thumb = tester.getCenter(_thumb);

    await tester.tapAt(Offset(thumb.dx + 130, thumb.dy));
    await tester.pumpAndSettle();

    expect(picked.single, greaterThan(2), reason: 'a stop right of Дунд');
  });

  testWidgets('a plain tap on the track reports exactly one answer',
      (tester) async {
    final picked = <int>[];
    await _pump(tester, onChanged: picked.add);

    await tester.tap(_thumb);
    await tester.pumpAndSettle();

    expect(picked, hasLength(1));
  });

  testWidgets('opens on an already chosen answer', (tester) async {
    await _pump(tester, selectedIndex: 4);
    expect(_facePosition(tester), closeTo(1, 1e-9));

    await _pump(tester, selectedIndex: 1);
    expect(_facePosition(tester), closeTo(0.25, 1e-9));
  });

  testWidgets('the big word follows the thumb', (tester) async {
    await _pump(tester);
    final before = tester.getCenter(find.text('МАШ САЙН')).dx;

    await tester.drag(_thumb, const Offset(400, 0));
    await tester.pumpAndSettle();

    // Маш сайн slid in from the right to the centre.
    expect(tester.getCenter(find.text('МАШ САЙН')).dx, lessThan(before));
  });

  testWidgets('reduce-motion jumps without animating', (tester) async {
    await _pump(tester, reduceMotion: true);

    await tester.tap(find.text('Сайн'));
    await tester.pump();

    expect(_facePosition(tester), closeTo(0.75, 1e-9));
  });

  testWidgets('screen readers can adjust it', (tester) async {
    final handle = tester.ensureSemantics();
    final picked = <int>[];
    await _pump(tester, onChanged: picked.add);

    final node = tester.getSemantics(find.byType(MoodSlider));
    expect(node.value, 'Дунд');
    tester.semantics.increase(find.semantics.byLabel(MoodSlider.semanticLabel));
    await tester.pumpAndSettle();

    expect(picked, [3]);
    handle.dispose();
  });

  testWidgets('five labels fit a 320pt phone at 1.3x text', (tester) async {
    await _pump(tester, width: 320, textScale: 1.3);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in kMoodLabels) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('the painters know how many stops the scale has', (tester) async {
    await _pump(tester);
    final face = tester.widget<CustomPaint>(_face).painter! as MoodFacePainter;
    expect(face.steps, 5);
  });

  group('a question from before 2026-10-21 (three stops)', () {
    const three = ['Муу', 'Дунд', 'Сайн'];

    testWidgets('shows its three labels and the right end picks Сайн',
        (tester) async {
      final picked = <int>[];
      await _pump(tester, labels: three, onChanged: picked.add);
      expect(find.text('Маш сайн'), findsNothing);
      for (final l in three) {
        expect(find.text(l), findsOneWidget);
      }

      await tester.drag(_thumb, const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(picked, [2]);
      final face =
          tester.widget<CustomPaint>(_face).painter! as MoodFacePainter;
      expect(face.steps, 3);
    });

    testWidgets('tapping Муу picks the first stop', (tester) async {
      final picked = <int>[];
      await _pump(tester, labels: three, onChanged: picked.add);
      await tester.tap(find.text('Муу'));
      await tester.pumpAndSettle();
      expect(picked, [0]);
      expect(_facePosition(tester), closeTo(0, 1e-9));
    });
  });

  testWidgets('choosing a label changes its colour, not its weight',
      (tester) async {
    await _pump(tester, selectedIndex: 4);
    await tester.pumpAndSettle();
    TextStyle style(String label) => tester
        .widget<AnimatedDefaultTextStyle>(find
            .ancestor(
                of: find.text(label),
                matching: find.byType(AnimatedDefaultTextStyle))
            .first) // the nearest one wraps the label
        .style;
    expect(style('Маш сайн').fontWeight, style('Маш муу').fontWeight);
    expect(style('Маш сайн').color, isNot(style('Маш муу').color));
  });
}
