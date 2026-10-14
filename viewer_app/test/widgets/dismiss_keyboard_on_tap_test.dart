import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/ui.dart';

void main() {
  late FocusNode first;
  late FocusNode second;
  late int buttonTaps;

  setUp(() {
    first = FocusNode();
    second = FocusNode();
    buttonTaps = 0;
  });
  tearDown(() {
    first.dispose();
    second.dispose();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => DismissKeyboardOnTap(child: child!),
          home: Scaffold(
            body: Column(
              children: [
                TextField(key: const Key('first'), focusNode: first),
                TextField(key: const Key('second'), focusNode: second),
                ElevatedButton(
                  onPressed: () => buttonTaps++,
                  child: const Text('Товч'),
                ),
                const Expanded(
                  child: SizedBox(key: Key('empty'), width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      );

  /// The user's request (2026-10-14): the keyboard used to go away only by
  /// scrolling; a tap on the screen must close it.
  testWidgets('a tap on an empty part of the screen closes the keyboard',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('first')));
    await tester.pump();
    expect(first.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byKey(const Key('empty')));
    await tester.pump();

    expect(first.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('tapping another field moves the focus there instead',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('first')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('second')));
    await tester.pump();

    expect(second.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('buttons keep working', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('first')));
    await tester.pump();

    await tester.tap(find.text('Товч'));
    await tester.pump();

    expect(buttonTaps, 1);
  });

  testWidgets('a tap with no field focused does nothing harmful',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('empty')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
