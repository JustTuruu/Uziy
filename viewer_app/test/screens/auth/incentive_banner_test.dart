import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/incentive_banner.dart';
import 'package:viewer_app/widgets/ui.dart';

/// The spec-verbatim message (docs/SPEC.md §4A). Must never change.
const _specMessage =
    'Та өөрийн нас, хүйс, байршлыг үнэн зөв оруулснаар өөрт тохирсон илүү '
    'олон, илүү өндөр дүнтэй видео судалгаануудыг хүлээн авч, урамшууллаа '
    'нэмэгдүүлэх боломжтой болно.';

Future<void> _pump(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: IncentiveBanner(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows exactly the spec message and nothing else',
      (tester) async {
    await _pump(tester);

    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(IncentiveBanner),
            matching: find.byType(Text),
          ),
        )
        .toList();
    expect(texts, hasLength(1), reason: 'the banner is title-less');
    expect(texts.single.data, _specMessage);
  });

  test('the expected string matches docs/SPEC.md §4A verbatim', () {
    final spec = File('../docs/SPEC.md');
    if (!spec.existsSync()) {
      markTestSkipped('docs/SPEC.md not found from ${Directory.current.path}');
      return;
    }
    // The spec quotes the message as a Markdown block quote over several
    // lines ("> ..."); join those lines back into one string.
    final joined = spec.readAsStringSync().replaceAll(RegExp(r'\r?\n> '), ' ');
    expect(joined, contains(_specMessage));
  });

  testWidgets('fits a 320pt screen at 1.3x text without overflow',
      (tester) async {
    await _pump(tester, width: 320, textScale: 1.3);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(_specMessage), findsOneWidget);
  });
}
