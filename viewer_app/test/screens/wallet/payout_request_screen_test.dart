import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/wallet/payout_request_screen.dart';
import 'package:viewer_app/screens/wallet/wallet_logic.dart';
import 'package:viewer_app/screens/wallet/wallet_widgets.dart';
import 'package:viewer_app/widgets/ui.dart';

import '../../support/fake_api.dart';

// Most tests exercise the form UI and validation only; the submit test
// answers through FakeApi.

Future<void> pumpPayout(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
  bool firstPayout = false,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
      home: PayoutRequestScreen(firstPayout: firstPayout),
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
    expect(_amountText(tester), '2,000');
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
    await pumpPayout(tester, firstPayout: true);
    expect(find.byType(StatusBanner), findsOneWidget);
    expect(find.textContaining('заавал таарсан'), findsOneWidget);
    expect(find.textContaining('is_verified'), findsNothing);
  });

  /// Regression (2026-10-14): the notice came back after the first payout.
  testWidgets('no first-payout banner unless it is the first payout',
      (tester) async {
    await pumpPayout(tester);
    expect(find.text('Эхний таталт'), findsNothing);
    expect(find.byType(StatusBanner), findsNothing);
  });

  testWidgets('quick amount chip fills the amount field', (tester) async {
    await pumpPayout(tester);
    await tester.tap(find.text('5,000 ₮'));
    await tester.pumpAndSettle();
    expect(_amountText(tester), '5,000');

    await tester.tap(find.text('10,000 ₮'));
    await tester.pumpAndSettle();
    expect(_amountText(tester), '10,000');
  });

  testWidgets('amount field accepts digits only', (tester) async {
    await pumpPayout(tester);
    await tester.enterText(_amountField, '12a3.4');
    await tester.pump();
    expect(_amountText(tester), '1,234');
  });

  /// The user's request (2026-10-14): the amount must be typable by hand,
  /// with the quick picks still there.
  testWidgets('a typed amount is grouped and no chip is selected',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPayout(tester);

    await tester.enterText(_amountField, '12500');
    await tester.pump();

    expect(_amountText(tester), '12,500');
    for (final chip in ['1,000 ₮', '2,000 ₮', '5,000 ₮', '10,000 ₮']) {
      expect(
          tester.getSemantics(find.text(chip)), isSemantics(isSelected: false));
    }
    expect(find.text(kQuickAmountsLabel), findsOneWidget);
    expect(find.text(kPayoutAmountHelper), findsOneWidget);
    handle.dispose();
  });

  testWidgets('typing a quick amount lights up its chip', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPayout(tester);

    await tester.enterText(_amountField, '5000');
    await tester.pump();

    expect(tester.getSemantics(find.text('5,000 ₮')),
        isSemantics(isSelected: true));
    handle.dispose();
  });

  testWidgets('tapping the amount selects it so typing replaces it',
      (tester) async {
    await pumpPayout(tester);

    await tester.tap(_amountField);
    await tester.pump();

    final controller = tester
        .widget<EditableText>(
          find.descendant(
              of: _amountField, matching: find.byType(EditableText)),
        )
        .controller;
    expect(controller.selection.start, 0);
    expect(controller.selection.end, controller.text.length);
  });

  testWidgets('a typed, grouped amount is sent as a plain number',
      (tester) async {
    final api = FakeApi.install((_) => const FakeReply(200, {
          'id': 1,
          'amount': 12500,
          'status': 'PENDING',
        }));
    await pumpPayout(tester);

    await tester.enterText(_amountField, '12500');
    await tester.enterText(_accountNumberField, '5001234567');
    await tester.enterText(find.byType(TextFormField).at(2), 'БОЛД');
    await _tapSubmit(tester);

    final body = api.callsTo('/viewer/payouts').single.body as Map;
    expect(body['amount'], 12500.0);
  });

  testWidgets('the amount field is a framed input', (tester) async {
    await pumpPayout(tester);
    final decorator = tester.widget<InputDecorator>(find.descendant(
      of: _amountField,
      matching: find.byType(InputDecorator),
    ));
    expect(decorator.decoration.enabledBorder, isA<OutlineInputBorder>());
    expect(decorator.decoration.filled, isTrue);
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

  /// The national ID is no longer asked for (owner, 2026-10-14).
  testWidgets('the form asks only for amount, account number and name',
      (tester) async {
    await pumpPayout(tester);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.textContaining('Регистр'), findsNothing);
  });

  testWidgets('no overflow on iPhone SE with 1.3x text', (tester) async {
    await pumpPayout(tester, size: const Size(320, 568), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await _tapSubmit(tester);
    expect(tester.takeException(), isNull);
  });
}
