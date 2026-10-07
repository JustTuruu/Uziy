import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/ui.dart';

Future<void> _pump(
  WidgetTester tester, {
  int length = 6,
  TextEditingController? controller,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onCompleted,
  bool hasError = false,
  bool enabled = true,
  double width = 390,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 800) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: OtpInput(
            length: length,
            controller: controller,
            onChanged: onChanged,
            onCompleted: onCompleted,
            hasError: hasError,
            enabled: enabled,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Types into the invisible field, like the soft keyboard would.
Future<void> _type(WidgetTester tester, String text) async {
  await tester.tap(find.byType(OtpInput));
  await tester.pump();
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

List<String?> _digits(WidgetTester tester) =>
    tester.widgetList<OtpBox>(find.byType(OtpBox)).map((b) => b.digit).toList();

int? _activeIndex(WidgetTester tester) {
  final boxes = tester.widgetList<OtpBox>(find.byType(OtpBox)).toList();
  final i = boxes.indexWhere((b) => b.active);
  return i < 0 ? null : i;
}

void main() {
  testWidgets('draws one box per digit, all empty at first', (tester) async {
    await _pump(tester);

    expect(find.byType(OtpBox), findsNWidgets(6));
    expect(_digits(tester), everyElement(isNull));
    expect(_activeIndex(tester), isNull);
  });

  testWidgets('typed digits fill the boxes left to right', (tester) async {
    await _pump(tester);

    await _type(tester, '123');

    expect(_digits(tester), ['1', '2', '3', null, null, null]);
  });

  testWidgets('the next empty box is highlighted while focused',
      (tester) async {
    await _pump(tester);

    await _type(tester, '123');

    expect(_activeIndex(tester), 3);
  });

  testWidgets('after the last digit the last box stays highlighted',
      (tester) async {
    await _pump(tester);

    await _type(tester, '123456');

    expect(_activeIndex(tester), 5);
  });

  testWidgets('non-digits are ignored', (tester) async {
    await _pump(tester);

    await _type(tester, '1a2-3');

    expect(_digits(tester), ['1', '2', '3', null, null, null]);
  });

  testWidgets('a pasted formatted code fills every box', (tester) async {
    await _pump(tester);

    await _type(tester, '123 456');

    expect(_digits(tester), ['1', '2', '3', '4', '5', '6']);
  });

  testWidgets('input beyond the length is cut off', (tester) async {
    await _pump(tester);

    await _type(tester, '12345678');

    expect(_digits(tester), ['1', '2', '3', '4', '5', '6']);
  });

  testWidgets('backspace empties the last box', (tester) async {
    await _pump(tester);
    await _type(tester, '123');

    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();

    expect(_digits(tester), ['1', '2', null, null, null, null]);
    expect(_activeIndex(tester), 2);
  });

  testWidgets('onChanged reports every edit', (tester) async {
    final seen = <String>[];
    await _pump(tester, onChanged: seen.add);

    await _type(tester, '1');
    await tester.enterText(find.byType(TextField), '12');

    expect(seen, ['1', '12']);
  });

  testWidgets('onCompleted fires once at full length, again after an edit',
      (tester) async {
    final done = <String>[];
    await _pump(tester, onCompleted: done.add);

    await _type(tester, '12345');
    expect(done, isEmpty);

    await tester.enterText(find.byType(TextField), '123456');
    expect(done, ['123456']);

    // Same full code again must not re-fire.
    await tester.enterText(find.byType(TextField), '123456');
    expect(done, ['123456']);

    await tester.enterText(find.byType(TextField), '12345');
    await tester.enterText(find.byType(TextField), '654321');
    expect(done, ['123456', '654321']);
  });

  testWidgets('clearing the controller empties the boxes', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(tester, controller: controller);
    await _type(tester, '123456');

    controller.clear();
    await tester.pump();

    expect(_digits(tester), everyElement(isNull));
  });

  testWidgets('a custom length draws that many boxes', (tester) async {
    final done = <String>[];
    await _pump(tester, length: 4, onCompleted: done.add);

    await _type(tester, '1234');

    expect(find.byType(OtpBox), findsNWidgets(4));
    expect(done, ['1234']);
  });

  testWidgets('hasError turns every box red', (tester) async {
    await _pump(tester, hasError: true);

    expect(
      tester.widgetList<OtpBox>(find.byType(OtpBox)).every((b) => b.error),
      isTrue,
    );
  });

  testWidgets('disabled input takes no digits and highlights nothing',
      (tester) async {
    await _pump(tester, enabled: false);

    await tester.tap(find.byType(OtpInput), warnIfMissed: false);
    await tester.pump();

    expect(_activeIndex(tester), isNull);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('announces itself to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    expect(find.bySemanticsLabel(OtpInput.semanticLabel), findsOneWidget);
    handle.dispose();
  });

  testWidgets('fits a 320pt phone at 1.3x text without overflow',
      (tester) async {
    await _pump(tester, width: 320, textScale: 1.3);
    await _type(tester, '123456');

    expect(tester.takeException(), isNull);
    final right = tester.getTopRight(find.byType(OtpBox).last).dx;
    expect(right, lessThanOrEqualTo(320));
  });

  testWidgets('works where intrinsic sizes are asked for (auth page shell)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: OtpInput(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(OtpBox), findsNWidgets(6));
  });
}
