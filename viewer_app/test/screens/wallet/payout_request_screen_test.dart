import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/wallet/payout_request_screen.dart';
import 'package:viewer_app/screens/wallet/wallet_widgets.dart';
import 'package:viewer_app/widgets/ui.dart';

// These tests only exercise the form UI and validation; none of them reaches
// a valid submit, so no network request is made.

Future<void> pumpPayout(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * 3;
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
      home: const PayoutRequestScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _amountField => find.byType(TextFormField).at(0);
Finder get _accountNumberField => find.byType(TextFormField).at(1);

String _amountText(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(of: _amountField, matching: find.byType(EditableText)),
    )
    .controller
    .text;

Future<void> _tapSubmit(WidgetTester tester) async {
  // Like a user closing the keyboard first: a focused field would otherwise
  // scroll itself back into view and push the button off-screen.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  final submit = find.text('Хүсэлт илгээх');
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens with 2,000 ₮ and Khan Bank preselected', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPayout(tester);

    expect(find.text('Мөнгө татах'), findsOneWidget); // app bar title
    expect(_amountText(tester), '2000');
    expect(
      tester.getSemantics(find.text('2,000 ₮')),
      isSemantics(isSelected: true),
    );
    await tester.ensureVisible(find.text('Khan Bank'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Khan Bank')),
      isSemantics(isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('first-payout info banner is shown without dev jargon', (
    tester,
  ) async {
    await pumpPayout(tester);
    expect(find.byType(StatusBanner), findsOneWidget);
    expect(find.textContaining('заавал таарсан'), findsOneWidget);
    expect(find.textContaining('is_verified'), findsNothing);
  });

  testWidgets('quick amount chip fills the amount field', (tester) async {
    await pumpPayout(tester);
    await tester.tap(find.text('5,000 ₮'));
    await tester.pumpAndSettle();
    expect(_amountText(tester), '5000');

    await tester.tap(find.text('10,000 ₮'));
    await tester.pumpAndSettle();
    expect(_amountText(tester), '10000');
  });

  testWidgets('amount field accepts digits only', (tester) async {
    await pumpPayout(tester);
    await tester.enterText(_amountField, '12a3.4');
    await tester.pump();
    expect(_amountText(tester), '1234');
  });

  testWidgets('tapping a bank tile selects it', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPayout(tester);
    await tester.ensureVisible(find.text('Golomt Bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Golomt Bank'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Golomt Bank')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Khan Bank')),
      isSemantics(isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('submitting an empty form shows every field error', (
    tester,
  ) async {
    await pumpPayout(tester);
    await _tapSubmit(tester);

    expect(find.text('Дансны дугаар дор хаяж 8 оронтой байна'), findsOneWidget);
    expect(
      find.text('Дансны эзэмшигчийн нэрийг бүтэн оруулна уу'),
      findsOneWidget,
    );
    expect(find.text('Регистрийн дугаар 10 тэмдэгттэй байна'), findsOneWidget);
    // Amount is prefilled with a valid 2,000.
    expect(find.text('Хамгийн бага дүн: 1,000 ₮'), findsNothing);
    // Still on the form: nothing was sent.
    expect(find.byType(PayoutSuccessSheet), findsNothing);
  });

  testWidgets('after a failed submit, fixing a field clears its error', (
    tester,
  ) async {
    await pumpPayout(tester);
    await _tapSubmit(tester);
    expect(find.text('Дансны дугаар дор хаяж 8 оронтой байна'), findsOneWidget);

    await tester.enterText(_accountNumberField, '12345678');
    await tester.pumpAndSettle();
    expect(find.text('Дансны дугаар дор хаяж 8 оронтой байна'), findsNothing);
  });

  testWidgets('amount below 1,000 is rejected', (tester) async {
    await pumpPayout(tester);
    await tester.enterText(_amountField, '500');
    await _tapSubmit(tester);
    expect(find.text('Хамгийн бага дүн: 1,000 ₮'), findsOneWidget);

    // A quick amount fixes it immediately.
    await tester.ensureVisible(find.text('1,000 ₮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1,000 ₮'));
    await tester.pumpAndSettle();
    expect(find.text('Хамгийн бага дүн: 1,000 ₮'), findsNothing);
  });

  testWidgets('national ID input stops at 10 characters', (tester) async {
    await pumpPayout(tester);
    final idField = find.byType(TextFormField).at(3);
    await tester.ensureVisible(idField);
    await tester.enterText(idField, 'АА999999999999');
    await tester.pump();
    final text = tester
        .widget<EditableText>(
          find.descendant(of: idField, matching: find.byType(EditableText)),
        )
        .controller
        .text;
    expect(text.length, 10);
  });

  testWidgets('no overflow on iPhone SE with 1.3x text', (tester) async {
    await pumpPayout(tester, size: const Size(320, 568), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await _tapSubmit(tester);
    expect(tester.takeException(), isNull);
  });
}
