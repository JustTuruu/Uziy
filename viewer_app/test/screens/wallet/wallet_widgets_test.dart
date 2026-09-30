import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/wallet/wallet_logic.dart';
import 'package:viewer_app/screens/wallet/wallet_widgets.dart';
import 'package:viewer_app/widgets/ui.dart';

/// Pumps [child] in the real theme. [width] bounds the content like a phone
/// column; [textScale] emulates the OS text size.
Future<void> pumpWallet(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
  double width = 360,
  double textScale = 1.0,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('WalletBalanceCard', () {
    testWidgets('shows the formatted balance and the verified label', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        WalletBalanceCard(
          balance: 3400,
          verified: true,
          progress: payoutProgress(3400),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Одоогийн үлдэгдэл'), findsOneWidget);
      expect(find.text('3,400 ₮'), findsOneWidget);
      expect(find.text(WalletVerifiedBadge.verifiedLabel), findsOneWidget);
      expect(find.text(WalletVerifiedBadge.unverifiedLabel), findsNothing);
      // Minimum reached: no progress meter.
      expect(find.byType(PayoutProgressMeter), findsNothing);
      expect(find.byType(CoinIcon), findsOneWidget);
    });

    testWidgets('unverified user gets the unverified label', (tester) async {
      await pumpWallet(
        tester,
        const WalletBalanceCard(balance: 1200, verified: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('1,200 ₮'), findsOneWidget);
      expect(find.text('Баталгаажаагүй'), findsOneWidget);
      expect(find.text('Баталгаажсан'), findsNothing);
    });

    testWidgets('rounds fractional balances like formatTugrik', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        const WalletBalanceCard(balance: 699.5, verified: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('700 ₮'), findsOneWidget);
    });

    testWidgets('below the minimum shows the payout meter', (tester) async {
      await pumpWallet(
        tester,
        WalletBalanceCard(
          balance: 400,
          verified: false,
          progress: payoutProgress(400),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PayoutProgressMeter), findsOneWidget);
      expect(find.text('Мөнгө татахад 600 ₮ дутуу'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
    });

    testWidgets('reduce motion shows the final balance in the first frame', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        const WalletBalanceCard(balance: 12500, verified: true),
        reduceMotion: true,
      );
      await tester.pump();
      expect(find.text('12,500 ₮'), findsOneWidget);
    });

    testWidgets('screen reader hears the verification state', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWallet(
        tester,
        const WalletBalanceCard(balance: 3400, verified: true),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Бүртгэл: Баталгаажсан'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('fits an iPhone SE column at 1.3x text with a big balance', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        WalletBalanceCard(
          balance: 9876543,
          verified: false,
          progress: payoutProgress(10),
        ),
        width: 280,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('PayoutProgressMeter', () {
    test('label copy', () {
      expect(
        PayoutProgressMeter.labelFor(payoutProgress(0)),
        'Мөнгө татахад 1,000 ₮ дутуу',
      );
      expect(
        PayoutProgressMeter.labelFor(payoutProgress(999)),
        'Мөнгө татахад 1 ₮ дутуу',
      );
    });

    testWidgets('bar width follows the fraction', (tester) async {
      await pumpWallet(
        tester,
        PayoutProgressMeter(progress: payoutProgress(250)),
        width: 300,
      );
      await tester.pumpAndSettle();
      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.25, 1e-9));
      expect(find.text('25%'), findsOneWidget);
    });
  });

  group('QuickAmountChips', () {
    testWidgets('renders every amount and reports taps', (tester) async {
      int? picked;
      await pumpWallet(
        tester,
        QuickAmountChips(selected: null, onSelected: (a) => picked = a),
      );
      for (final label in ['1,000 ₮', '2,000 ₮', '5,000 ₮', '10,000 ₮']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('5,000 ₮'));
      await tester.pumpAndSettle();
      expect(picked, 5000);
    });

    testWidgets('marks the selected chip for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWallet(
        tester,
        QuickAmountChips(selected: 2000, onSelected: (_) {}),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('2,000 ₮')),
        isSemantics(
          label: '2,000 ₮',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('four across when wide, two per row when narrow', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        QuickAmountChips(selected: null, onSelected: (_) {}),
        width: 400,
      );
      final y1 = tester.getCenter(find.text('1,000 ₮')).dy;
      expect(tester.getCenter(find.text('10,000 ₮')).dy, y1);

      await pumpWallet(
        tester,
        QuickAmountChips(selected: null, onSelected: (_) {}),
        width: 240,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final top = tester.getCenter(find.text('1,000 ₮')).dy;
      expect(tester.getCenter(find.text('2,000 ₮')).dy, top);
      expect(tester.getCenter(find.text('5,000 ₮')).dy, greaterThan(top));
    });
  });

  group('BankPicker', () {
    testWidgets('lists all banks and reports the tapped one', (tester) async {
      String? picked;
      await pumpWallet(
        tester,
        BankPicker(selected: kDefaultPayoutBank, onSelected: (b) => picked = b),
      );
      for (final b in kPayoutBanks) {
        expect(find.text(b), findsOneWidget);
      }
      await tester.tap(find.text('TDB'));
      await tester.pumpAndSettle();
      expect(picked, 'TDB');
    });

    testWidgets('only the selected bank is marked selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWallet(
        tester,
        BankPicker(selected: 'Golomt Bank', onSelected: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Golomt Bank')),
        isSemantics(
          label: 'Golomt Bank',
          isSelected: true,
          isButton: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Khan Bank')),
        isSemantics(label: 'Khan Bank', isSelected: false),
      );
      handle.dispose();
    });

    testWidgets('no overflow on a narrow phone with large text', (
      tester,
    ) async {
      await pumpWallet(
        tester,
        BankPicker(selected: kDefaultPayoutBank, onSelected: (_) {}),
        width: 280,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('HowItWorksCard', () {
    testWidgets('shows the three steps in order', (tester) async {
      await pumpWallet(tester, const HowItWorksCard(), width: 280);
      await tester.pumpAndSettle();
      final xs = [
        for (final t in ['Үзэх', 'Хариулах', 'Авах'])
          tester.getCenter(find.text(t)).dx,
      ];
      expect(xs[0], lessThan(xs[1]));
      expect(xs[1], lessThan(xs[2]));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 1.3x text on a narrow column', (tester) async {
      await pumpWallet(
        tester,
        const HowItWorksCard(),
        width: 280,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('PayoutSuccessSheet', () {
    testWidgets('shows the confirmation, summary and closes via Ойлголоо', (
      tester,
    ) async {
      var done = 0;
      await pumpWallet(
        tester,
        PayoutSuccessSheet(
          amount: 5000,
          bank: 'Golomt Bank',
          onDone: () => done++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Хүсэлт хүлээн авлаа'), findsOneWidget);
      expect(find.text(PayoutSuccessSheet.message), findsOneWidget);
      expect(find.text('5,000 ₮'), findsOneWidget);
      expect(find.text('Golomt Bank'), findsOneWidget);
      // No developer jargon in user-facing copy.
      expect(find.textContaining('is_verified'), findsNothing);

      await tester.ensureVisible(find.text('Ойлголоо'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ойлголоо'));
      await tester.pumpAndSettle();
      expect(done, 1);
    });
  });

  group('WalletCardSkeleton', () {
    testWidgets('renders a loading placeholder', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWallet(tester, const WalletCardSkeleton());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Skeleton), findsNWidgets(5));
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Ачаалж байна'), findsOneWidget);
      handle.dispose();
    });
  });

  group('WalletNote', () {
    testWidgets('shows its text', (tester) async {
      await pumpWallet(tester, const WalletNote(text: 'Тэмдэглэл'));
      expect(find.text('Тэмдэглэл'), findsOneWidget);
    });
  });

  test('walletErrorSnackBar carries the message', () {
    final bar = walletErrorSnackBar('Алдаа');
    expect(bar.content, isA<Row>());
    final row = bar.content as Row;
    final text = (row.children.last as Expanded).child as Text;
    expect(text.data, 'Алдаа');
  });
}
