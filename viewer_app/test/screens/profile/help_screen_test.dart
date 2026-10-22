import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/profile/help_content.dart';
import 'package:viewer_app/screens/profile/help_screen.dart';
import 'package:viewer_app/screens/wallet/wallet_logic.dart'
    show kPayoutMinimumLabel;
import 'package:viewer_app/widgets/ui.dart';

Future<void> _pumpHelp(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: app!,
      ),
      home: const HelpScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

List<ChatBubble> _bubbles(WidgetTester tester) => tester
    .widgetList<ChatBubble>(find.byType(ChatBubble, skipOffstage: false))
    .toList();

void main() {
  testWidgets('a chat: greeting, then question and answer for every item',
      (tester) async {
    await _pumpHelp(tester);

    expect(find.text(kHelpTitle), findsOneWidget);
    final bubbles = _bubbles(tester);
    expect(bubbles, hasLength(1 + 2 * kFaqItems.length));
    expect(bubbles.first.text, kHelpGreeting);
    expect(bubbles.first.fromViewer, isFalse);
    for (var i = 0; i < kFaqItems.length; i++) {
      final q = bubbles[1 + 2 * i];
      final a = bubbles[2 + 2 * i];
      expect(q.text, kFaqItems[i].question);
      expect(q.fromViewer, isTrue);
      expect(a.text, kFaqItems[i].answer);
      expect(a.fromViewer, isFalse);
    }
  });

  testWidgets('every answer is readable without tapping anything',
      (tester) async {
    await _pumpHelp(tester);
    expect(find.text(kFaqItems.first.answer), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(kFaqItems.last.answer),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(kFaqItems.last.answer), findsOneWidget);
  });

  testWidgets('questions sit on the right, answers on the left with the coin',
      (tester) async {
    await _pumpHelp(tester);
    final screenWidth = tester.view.physicalSize.width / 3;
    final q = tester.getRect(find.text(kFaqItems.first.question));
    final a = tester.getRect(find.text(kFaqItems.first.answer));
    expect(q.center.dx, greaterThan(screenWidth / 2));
    expect(a.left, lessThan(screenWidth / 3));
    expect(q.top, lessThan(a.top), reason: 'the question comes first');
    expect(find.byType(CoinIcon), findsWidgets);
  });

  testWidgets('a bubble never spans the whole width', (tester) async {
    await _pumpHelp(tester);
    final screenWidth = tester.view.physicalSize.width / 3;
    for (final f in [
      find.text(kFaqItems.first.question),
      find.text(kFaqItems.first.answer),
    ]) {
      expect(tester.getRect(f).width,
          lessThanOrEqualTo(screenWidth * ChatBubble.maxWidthFactor));
    }
  });

  testWidgets('the viewer\'s bubble is the action colour with readable ink',
      (tester) async {
    await _pumpHelp(tester);
    final text = tester.widget<Text>(find.text(kFaqItems.first.question));
    expect(text.style?.color, AppColors.onPrimary);
  });

  for (final dark in [false, true]) {
    testWidgets('fits a 320pt phone at 1.3x text (dark: $dark)',
        (tester) async {
      await _pumpHelp(tester, width: 320, textScale: 1.3, dark: dark);
      expect(tester.takeException(), isNull);
    });
  }

  // Owner, 2026-10-21: 'Яагаад надад видео цөөн харагдаж байна?' was removed.
  test('the "why so few videos" question is gone', () {
    expect(kFaqItems.map((i) => i.question),
        isNot(contains(startsWith('Яагаад надад видео цөөн'))));
  });

  test('the payout answer gives the current minimum', () {
    final payout = kFaqItems.singleWhere((i) => i.question.contains('татах'));
    expect(payout.answer, contains(kPayoutMinimumLabel));
    expect(payout.answer, isNot(contains('1,000 ₮')));
  });

  test('every FAQ entry has a question and an answer', () {
    for (final item in kFaqItems) {
      expect(item.question.trim(), isNotEmpty);
      expect(item.answer.trim(), isNotEmpty);
    }
  });
}
