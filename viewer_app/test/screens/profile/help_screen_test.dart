import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/profile/help_content.dart';
import 'package:viewer_app/screens/profile/help_screen.dart';
import 'package:viewer_app/widgets/ui.dart';

Future<void> _pumpHelp(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.dark(), home: const HelpScreen()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every question with its answers hidden', (tester) async {
    await _pumpHelp(tester);

    expect(find.text(kHelpTitle), findsOneWidget);
    expect(find.byType(FaqTile), findsNWidgets(kFaqItems.length));
    expect(find.text(kFaqItems.first.question), findsOneWidget);
    expect(find.text(kFaqItems.first.answer), findsNothing);
  });

  testWidgets('tapping a question reveals its answer', (tester) async {
    await _pumpHelp(tester);

    await tester.tap(find.text(kFaqItems.first.question));
    await tester.pumpAndSettle();

    expect(find.text(kFaqItems.first.answer), findsOneWidget);
  });

  testWidgets('opening another question closes the first', (tester) async {
    await _pumpHelp(tester);

    await tester.tap(find.text(kFaqItems[0].question));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kFaqItems[1].question));
    await tester.pumpAndSettle();

    expect(find.text(kFaqItems[0].answer), findsNothing);
    expect(find.text(kFaqItems[1].answer), findsOneWidget);
  });

  testWidgets('tapping the open question closes it', (tester) async {
    await _pumpHelp(tester);

    await tester.tap(find.text(kFaqItems.first.question));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kFaqItems.first.question));
    await tester.pumpAndSettle();

    expect(find.text(kFaqItems.first.answer), findsNothing);
  });

  test('every FAQ entry has a question and an answer', () {
    for (final item in kFaqItems) {
      expect(item.question.trim(), isNotEmpty);
      expect(item.answer.trim(), isNotEmpty);
    }
  });
}
