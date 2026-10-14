import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/payout_request.dart';
import 'package:viewer_app/models/view_history_item.dart';
import 'package:viewer_app/screens/profile/history_screen.dart' show HistoryRow;
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
      theme: AppTheme.light(),
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
      // Bank-card furniture.
      expect(find.byType(UziyWordmark), findsOneWidget);
      expect(find.byType(CardChip), findsOneWidget);
      expect(find.text(WalletBalanceCard.cardTitle), findsOneWidget);
    });

    testWidgets('prints the masked phone where a card has its number',
        (tester) async {
      await pumpWallet(
        tester,
        const WalletBalanceCard(
            balance: 0, verified: false, phoneNumber: '99119911'),
      );
      await tester.pumpAndSettle();
      expect(find.text('•••• 9911'), findsOneWidget);
      expect(find.textContaining('9911991'), findsNothing);
    });

    /// The user's request (2026-10-14): the card shows whose wallet it is.
    testWidgets('prints the holder name above the number', (tester) async {
      await pumpWallet(
        tester,
        const WalletBalanceCard(
          balance: 3400,
          verified: true,
          phoneNumber: '99119911',
          holderName: 'БОЛД ЭРДЭНЭ',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('БОЛД ЭРДЭНЭ'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('БОЛД ЭРДЭНЭ')).dy,
        lessThan(tester.getTopLeft(find.text('•••• 9911')).dy),
      );
      // The extra line still fits the bank-card shape on a phone.
      final size = tester.getSize(find.byType(WalletBalanceCard));
      expect(
          size.height, closeTo(size.width / WalletBalanceCard.aspectRatio, 1));
    });

    testWidgets('no name line without a holder name', (tester) async {
      await pumpWallet(
        tester,
        const WalletBalanceCard(balance: 0, verified: false),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(WalletBalanceCard.holderLabel),
        findsNothing,
      );
    });

    testWidgets('a very long name is cut, never overflows', (tester) async {
      await pumpWallet(
        tester,
        WalletBalanceCard(
          balance: 3400,
          verified: true,
          holderName: 'БОЛДБААТАР ' * 6,
        ),
        width: 300,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('has bank-card proportions', (tester) async {
      await pumpWallet(
        tester,
        const WalletBalanceCard(balance: 3400, verified: true),
        width: 340,
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(WalletBalanceCard));
      expect(size.width, 340);
      expect(size.height, closeTo(340 / WalletBalanceCard.aspectRatio, 1));
    });

    testWidgets('the payout meter sits under the card, not on it',
        (tester) async {
      await pumpWallet(
        tester,
        WalletBalanceCard(
          balance: 400,
          verified: false,
          progress: payoutProgress(400),
        ),
        width: 340,
      );
      await tester.pumpAndSettle();
      final chipBottom = tester.getBottomLeft(find.text('•••• ••••')).dy;
      final meterTop = tester.getTopLeft(find.byType(PayoutProgressMeter)).dy;
      expect(meterTop, greaterThan(chipBottom));
    });

    testWidgets('verified badge stays legible on the card in dark mode',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: WalletBalanceCard(balance: 10, verified: true),
        ),
      ));
      await tester.pumpAndSettle();
      final label =
          tester.widget<Text>(find.text(WalletVerifiedBadge.verifiedLabel));
      // Fixed card artwork: the badge keeps forest-on-white in both themes.
      expect(label.style?.color, AppColors.primary);
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

  group('BankLogo', () {
    const palette = [Color(0xFF145C45), Color(0xFF104C39)];

    testWidgets('without a logo it shows the monogram', (tester) async {
      await pumpWallet(
        tester,
        const BankLogo(name: 'Khan Bank', palette: palette),
      );
      expect(find.text('K'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('with a bundled logo it shows the image, not the monogram',
        (tester) async {
      await pumpWallet(
        tester,
        const BankLogo(
          name: 'Khan Bank',
          palette: palette,
          logoAsset: 'assets/logo.png',
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('K'), findsNothing);
    });

    testWidgets('the logo fills a rounded square edge to edge', (tester) async {
      await pumpWallet(
        tester,
        const Center(
          child: BankLogo(
            name: 'Khan Bank',
            palette: palette,
            logoAsset: 'assets/banks/khan_bank.png',
          ),
        ),
      );
      final box = tester.widget<Container>(
        find.ancestor(of: find.byType(Image), matching: find.byType(Container)),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.rectangle);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(BankLogo.cornerRadius),
      );
      expect(box.padding, isNull);
      expect(
        tester.getSize(find.byType(Image)),
        const Size.square(BankLogo.size),
      );
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    });

    testWidgets('a missing logo file falls back to the monogram',
        (tester) async {
      await pumpWallet(
        tester,
        const BankLogo(
          name: 'Golomt Bank',
          palette: palette,
          logoAsset: 'assets/banks/does_not_exist.png',
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50),
          ));
      await tester.pump();
      expect(find.text('G'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

    testWidgets('gives every bank its logo path', (tester) async {
      await pumpWallet(
        tester,
        BankPicker(selected: kDefaultPayoutBank, onSelected: (_) {}),
      );
      final logos = tester.widgetList<BankTile>(find.byType(BankTile));
      for (final tile in logos) {
        expect(tile.logoAsset, kBankLogoAssets[tile.name]);
      }
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
      // Seven blocks on the card (mark, title, chip, label, balance, number,
      // badge) plus the payout button.
      expect(find.byType(Skeleton), findsNWidgets(8));
      final card = tester.getSize(find.byType(AspectRatio).first);
      expect(card.width / card.height,
          closeTo(WalletBalanceCard.aspectRatio, 0.01));
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
    final bar = walletErrorSnackBar('Алдаа', palette: const AppPalette(false));
    expect(bar.content, isA<Row>());
    final row = bar.content as Row;
    final text = (row.children.last as Expanded).child as Text;
    expect(text.data, 'Алдаа');
  });

  /// Regression (2026-10-13): the payout screen built it without a palette,
  /// so the error icon kept the light red in dark mode.
  test('walletErrorSnackBar takes its colours from the given palette', () {
    const dark = AppPalette(true);
    final bar = walletErrorSnackBar('Алдаа', palette: dark);
    final icon = (bar.content as Row).children.first as Icon;
    expect(icon.color, dark.dangerLight);
  });

  group('WalletHistorySection', () {
    final now = DateTime(2026, 10, 14, 12);
    final reward = ViewHistoryItem(
      campaignId: 1,
      title: 'Шинэ 5G багц',
      companyName: 'MobiCom',
      rewardPaid: 700,
      watchedAt: DateTime(2026, 10, 14, 9),
    );
    PayoutRequest payout(PayoutStatus status, {String? reason}) =>
        PayoutRequest(
          id: 7,
          amount: 5000,
          bank: 'Khan Bank',
          status: status,
          requestedAt: DateTime(2026, 10, 14, 10),
          decidedAt: status == PayoutStatus.pending
              ? null
              : DateTime(2026, 10, 14, 11),
          rejectReason: reason,
        );

    testWidgets('empty: says how the history fills up', (tester) async {
      await pumpWallet(
        tester,
        WalletHistorySection(rewards: const [], payouts: const [], now: now),
      );
      expect(find.text(kWalletHistoryTitle), findsOneWidget);
      expect(find.text(kWalletHistoryEmptyTitle), findsOneWidget);
      expect(find.byType(WalletTotalsCard), findsNothing);
    });

    testWidgets('shows income, spending and both kinds of rows',
        (tester) async {
      await pumpWallet(
        tester,
        SingleChildScrollView(
          child: WalletHistorySection(
            rewards: [reward],
            payouts: [payout(PayoutStatus.approved)],
            now: now,
          ),
        ),
      );
      expect(find.text('+700 ₮'), findsNWidgets(2)); // total + the row
      expect(find.text('-5,000 ₮'), findsNWidgets(2));
      expect(find.byType(HistoryRow), findsOneWidget);
      expect(find.text('Мөнгө татсан · Khan Bank'), findsOneWidget);
      expect(find.textContaining('Дансанд шилжүүлсэн · Өнөөдөр · 11:00'),
          findsOneWidget);
      // Newest first: the payout (10:00) above the reward (09:00).
      expect(
        tester.getTopLeft(find.byType(PayoutHistoryRow)).dy,
        lessThan(tester.getTopLeft(find.byType(HistoryRow)).dy),
      );
    });

    testWidgets('a long history scrolls inside its own box', (tester) async {
      final many = [
        for (var i = 0; i < 30; i++)
          ViewHistoryItem(
            campaignId: i,
            title: 'Видео $i',
            companyName: 'MobiCom',
            rewardPaid: 700,
            watchedAt: DateTime(2026, 10, 14, 9).subtract(Duration(hours: i)),
          ),
      ];
      await pumpWallet(
        tester,
        SingleChildScrollView(
          child: WalletHistorySection(
            rewards: many,
            payouts: const [],
            now: now,
          ),
        ),
      );

      final box = find.byType(GroupedCard);
      expect(tester.getSize(box).height, kWalletHistoryBoxHeight);
      final oldest = find.text('Видео 29');
      expect(oldest.hitTestable(), findsNothing);

      await tester.dragUntilVisible(
        oldest,
        find.descendant(of: box, matching: find.byType(Scrollable)),
        const Offset(0, -200),
      );
      expect(oldest.hitTestable(), findsOneWidget);
      expect(tester.getSize(box).height, kWalletHistoryBoxHeight);
    });

    testWidgets(
        'a rejected payout is struck through, shows the reason and '
        'does not count as spending', (tester) async {
      await pumpWallet(
        tester,
        SingleChildScrollView(
          child: WalletHistorySection(
            rewards: [reward],
            payouts: [payout(PayoutStatus.rejected, reason: 'Нэр таарахгүй')],
            now: now,
          ),
        ),
      );
      expect(
          find.textContaining('Татгалзсан · хэтэвчинд буцсан · Нэр таарахгүй'),
          findsOneWidget);
      final amount = tester.widget<Text>(find.text('-5,000 ₮'));
      expect(amount.style?.decoration, TextDecoration.lineThrough);
      expect(find.text('0 ₮'), findsOneWidget, reason: 'spending total');
    });
  });

  group('WalletTotalsCard', () {
    testWidgets('money in sits on the left, money out on the right',
        (tester) async {
      await pumpWallet(
          tester, const WalletTotalsCard(income: 4100, spending: 4000));
      await tester.pumpAndSettle();

      final card = tester.getRect(find.byType(WalletTotalsCard));
      final income = tester.getRect(find.text('+4,100 ₮'));
      final spending = tester.getRect(find.text('-4,000 ₮'));
      final spendingLabel = tester.getRect(find.text(kWalletSpendingLabel));

      expect(income.left - card.left, lessThan(card.width / 4));
      expect(card.right - spending.right, lessThan(card.width / 4));
      // The label and the amount share one right edge.
      expect(spendingLabel.right, closeTo(spending.right, 1));
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byIcon(AppIcons.moneyIn), findsOneWidget);
      expect(find.byIcon(AppIcons.moneyOut), findsOneWidget);
    });

    testWidgets('each side reads as one phrase to a screen reader',
        (tester) async {
      await pumpWallet(
          tester, const WalletTotalsCard(income: 4100, spending: 4000));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('$kWalletIncomeLabel: +4,100 ₮'),
          findsOneWidget);
      expect(find.bySemanticsLabel('$kWalletSpendingLabel: -4,000 ₮'),
          findsOneWidget);
    });

    testWidgets('big amounts and large text still fit', (tester) async {
      await pumpWallet(
        tester,
        const WalletTotalsCard(income: 12345678, spending: 9876543),
        width: 320,
        textScale: 1.6,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
