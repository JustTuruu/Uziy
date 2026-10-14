import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/payout_request.dart';
import 'package:viewer_app/models/view_history_item.dart';
import 'package:viewer_app/screens/wallet/wallet_logic.dart';

PayoutRequest _payout(
  int id,
  PayoutStatus status, {
  DateTime? requestedAt,
  DateTime? decidedAt,
  String? reason,
}) =>
    PayoutRequest(
      id: id,
      amount: 5000,
      bank: 'Khan Bank',
      status: status,
      requestedAt: requestedAt ?? DateTime(2026, 10, 14, 9),
      decidedAt: decidedAt,
      rejectReason: reason,
    );

ViewHistoryItem _reward(int id, DateTime at, {double paid = 700}) =>
    ViewHistoryItem(
      campaignId: id,
      title: 'Видео $id',
      companyName: 'MobiCom',
      rewardPaid: paid,
      watchedAt: at,
    );

void main() {
  group('wallet history', () {
    test('rewards and payouts merge into one list, newest first', () {
      final entries = buildWalletHistory(
        [
          _reward(1, DateTime(2026, 10, 10)),
          _reward(2, DateTime(2026, 10, 13)),
        ],
        [_payout(7, PayoutStatus.pending, requestedAt: DateTime(2026, 10, 12))],
      );
      expect(
          entries.map((e) => switch (e) {
                RewardEntry(:final reward) => 'r${reward.campaignId}',
                PayoutEntry(:final payout) => 'p${payout.id}',
              }),
          ['r2', 'p7', 'r1']);
    });

    test('income sums the rewards', () {
      expect(walletIncome(const []), 0);
      expect(
        walletIncome([
          _reward(1, DateTime(2026), paid: 700),
          _reward(2, DateTime(2026), paid: 500),
        ]),
        1200,
      );
    });

    test('spending counts pending and approved, not refunded requests', () {
      expect(
        walletSpending([
          _payout(1, PayoutStatus.approved),
          _payout(2, PayoutStatus.pending),
          _payout(3, PayoutStatus.rejected),
        ]),
        10000,
      );
    });

    test('row copy', () {
      expect(payoutEntryTitle(_payout(1, PayoutStatus.pending)),
          'Мөнгө татсан · Khan Bank');
      expect(payoutEntryStatus(_payout(1, PayoutStatus.pending)),
          'Хянагдаж байна');
      expect(payoutEntryStatus(_payout(1, PayoutStatus.approved)),
          'Дансанд шилжүүлсэн');
      expect(payoutEntryStatus(_payout(1, PayoutStatus.rejected)),
          'Татгалзсан · хэтэвчинд буцсан');
    });
  });

  group('payout status on the wallet', () {
    test('polls only while something waits for the admin', () {
      expect(hasPendingPayout(const []), isFalse);
      expect(hasPendingPayout([_payout(1, PayoutStatus.approved)]), isFalse);
      expect(
        hasPendingPayout([
          _payout(1, PayoutStatus.approved),
          _payout(2, PayoutStatus.pending),
        ]),
        isTrue,
      );
    });

    test('newlyDecided finds requests that were waiting and are now decided',
        () {
      final before = [
        _payout(1, PayoutStatus.pending),
        _payout(2, PayoutStatus.pending),
        _payout(3, PayoutStatus.rejected),
      ];
      final after = [
        _payout(1, PayoutStatus.approved),
        _payout(2, PayoutStatus.pending),
        _payout(3, PayoutStatus.rejected),
        _payout(4, PayoutStatus.approved),
      ];
      expect(newlyDecided(before, after).map((p) => p.id), [1]);
      expect(newlyDecided(after, after), isEmpty);
    });

    test('decision copy for the snack bar', () {
      expect(payoutDecisionMessage(_payout(1, PayoutStatus.approved)),
          '5,000 ₮ татах хүсэлт тань батлагдлаа');
      expect(payoutDecisionMessage(_payout(1, PayoutStatus.rejected)),
          contains('хэтэвчинд буцлаа'));
    });
  });

  group('maskedCardNumber', () {
    test('keeps only the last four digits', () {
      expect(maskedCardNumber('99119911'), '•••• 9911');
      expect(maskedCardNumber('+976 8800 1234'), '•••• 1234');
    });

    test('shows dots only when there is no usable number', () {
      expect(maskedCardNumber(null), '•••• ••••');
      expect(maskedCardNumber(''), '•••• ••••');
      expect(maskedCardNumber('12'), '•••• ••••');
    });
  });

  group('payoutProgress', () {
    test('empty wallet: nothing collected, full minimum missing', () {
      final p = payoutProgress(0);
      expect(p.fraction, 0);
      expect(p.remaining, 1000);
      expect(p.minimum, kPayoutMinimum);
      expect(p.reached, isFalse);
    });

    test('partway: 400 of 1,000 is 40% with 600 missing', () {
      final p = payoutProgress(400);
      expect(p.fraction, closeTo(0.4, 1e-9));
      expect(p.remaining, 600);
      expect(p.reached, isFalse);
    });

    test('999 is 1 ₮ short', () {
      final p = payoutProgress(999);
      expect(p.fraction, closeTo(0.999, 1e-9));
      expect(p.remaining, 1);
      expect(p.reached, isFalse);
    });

    test('a fractional balance just under the minimum is never "0 short"', () {
      final p = payoutProgress(999.6);
      expect(p.remaining, 1);
      expect(p.reached, isFalse);
      expect(p.fraction, lessThan(1));
    });

    test('exactly the minimum is reached', () {
      final p = payoutProgress(1000);
      expect(p.fraction, 1);
      expect(p.remaining, 0);
      expect(p.reached, isTrue);
    });

    test('above the minimum is clamped to 100%', () {
      final p = payoutProgress(5000);
      expect(p.fraction, 1);
      expect(p.remaining, 0);
      expect(p.reached, isTrue);
    });

    test('negative balance counts as 0', () {
      final p = payoutProgress(-500);
      expect(p.fraction, 0);
      expect(p.remaining, 1000);
      expect(p.reached, isFalse);
    });

    test('NaN / infinity count as 0', () {
      expect(payoutProgress(double.nan), payoutProgress(0));
      expect(payoutProgress(double.infinity), payoutProgress(0));
      expect(payoutProgress(double.negativeInfinity), payoutProgress(0));
    });

    test('custom minimum', () {
      final p = payoutProgress(250, minimum: 500);
      expect(p.fraction, closeTo(0.5, 1e-9));
      expect(p.remaining, 250);
      expect(p.minimum, 500);
    });

    test('non-positive minimum is always reached (no division by zero)', () {
      expect(payoutProgress(0, minimum: 0).reached, isTrue);
      expect(payoutProgress(0, minimum: 0).fraction, 1);
      expect(payoutProgress(10, minimum: -5).reached, isTrue);
    });

    test('value equality', () {
      expect(payoutProgress(400), payoutProgress(400));
      expect(payoutProgress(400).hashCode, payoutProgress(400).hashCode);
      expect(payoutProgress(400), isNot(payoutProgress(401)));
    });
  });

  group('canRequestPayout (same gate as before: loaded and >= 1,000)', () {
    test('not loaded yet', () => expect(canRequestPayout(null), isFalse));
    test('0', () => expect(canRequestPayout(0), isFalse));
    test('999', () => expect(canRequestPayout(999), isFalse));
    test('999.99', () => expect(canRequestPayout(999.99), isFalse));
    test('1000', () => expect(canRequestPayout(1000), isTrue));
    test('5000', () => expect(canRequestPayout(5000), isTrue));
    test('negative', () => expect(canRequestPayout(-1), isFalse));
    test('agrees with payoutProgress.reached', () {
      for (final b in [0, 1, 500, 999, 999.5, 1000, 1000.1, 7000]) {
        expect(canRequestPayout(b), payoutProgress(b).reached, reason: '$b');
      }
    });
  });

  group('quick amounts', () {
    test('offered amounts are all at or above the minimum', () {
      expect(kQuickPayoutAmounts, [1000, 2000, 5000, 10000]);
      for (final a in kQuickPayoutAmounts) {
        expect(a, greaterThanOrEqualTo(kPayoutMinimum));
      }
    });

    test('quickAmountValue writes the grouped amount, caret at the end', () {
      final v = quickAmountValue(5000);
      expect(v.text, '5,000');
      expect(v.selection.isCollapsed, isTrue);
      expect(v.selection.baseOffset, 5);
      expect(payoutAmountOf(v.text), 5000);
    });

    test('quickAmountValue text passes the amount validator', () {
      for (final a in kQuickPayoutAmounts) {
        expect(validatePayoutAmount(quickAmountValue(a).text), isNull);
      }
    });

    test('selectedQuickAmount matches exact chip values only', () {
      expect(selectedQuickAmount('2000'), 2000);
      expect(selectedQuickAmount('2,000'), 2000);
      expect(selectedQuickAmount(' 5000 '), 5000);
      expect(selectedQuickAmount('10000'), 10000);
      expect(selectedQuickAmount('2500'), isNull);
      expect(selectedQuickAmount(''), isNull);
      expect(selectedQuickAmount('abc'), isNull);
      expect(selectedQuickAmount('300', amounts: const [300]), 300);
    });
  });

  group('typed payout amount', () {
    TextEditingValue type(String text, {int? caret}) =>
        const PayoutAmountFormatter().formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: caret ?? text.length),
          ),
        );

    test('groups thousands as the user types', () {
      expect(type('1').text, '1');
      expect(type('1000').text, '1,000');
      expect(type('12500').text, '12,500');
      expect(type('1234567').text, '1,234,567');
    });

    test('keeps digits only, drops leading zeros', () {
      expect(type('12a3.4').text, '1,234');
      expect(type('0005000').text, '5,000');
      expect(type('0').text, '');
      expect(type('').text, '');
    });

    test('stops at the maximum length', () {
      expect(payoutAmountOf(type('12345678901234').text), 123456789);
    });

    test('the caret stays after the same digit when editing in the middle', () {
      // '1,2|00' after typing a 2 between 1 and 0 in '1,000' -> '12,000'.
      final v = type('1,2000', caret: 3);
      expect(v.text, '12,000');
      expect(v.text.substring(0, v.selection.baseOffset), '12');
    });

    test('payoutAmountOf reads the number back', () {
      expect(payoutAmountOf('12,500'), 12500);
      expect(payoutAmountOf('5000'), 5000);
      expect(payoutAmountOf(''), isNull);
      expect(payoutAmountOf(null), isNull);
    });
  });

  group('walletCardName', () {
    final paid = PayoutRequest(
      id: 1,
      amount: 2000,
      bank: 'Khan Bank',
      status: PayoutStatus.approved,
      requestedAt: DateTime(2026, 10, 14),
      accountName: 'GGGG',
    );

    /// Regression (2026-10-14): the card showed a test account name ('GGGG')
    /// typed on a payout; the registered name now wins.
    test('the registered name wins, given name first, in capitals', () {
      expect(
        walletCardName(
            lastName: 'Оюун-Эрдэнэ', firstName: 'Төрболд', payouts: [paid]),
        'ТӨРБОЛД ОЮУН-ЭРДЭНЭ',
      );
    });

    test('an account from before names were asked falls back to the payout',
        () {
      expect(walletCardName(payouts: [paid]), 'GGGG');
      expect(walletCardName(lastName: ' ', firstName: '', payouts: [paid]),
          'GGGG');
    });

    test('nothing at all gives no name', () {
      expect(walletCardName(payouts: const []), isNull);
    });
  });

  group('cardHolderName', () {
    PayoutRequest req(PayoutStatus status, String? name, int day) =>
        PayoutRequest(
          id: day,
          amount: 2000,
          bank: 'Khan Bank',
          status: status,
          requestedAt: DateTime(2026, 10, day),
          accountName: name,
        );

    test('none before any payout', () {
      expect(cardHolderName(const []), isNull);
    });

    test("the newest usable request's name, in capitals", () {
      expect(
        cardHolderName([
          req(PayoutStatus.approved, 'Болд Эрдэнэ', 1),
          req(PayoutStatus.pending, 'Болд Эрдэнэбат', 5),
        ]),
        'БОЛД ЭРДЭНЭБАТ',
      );
    });

    test('a rejected request never names the card', () {
      expect(
        cardHolderName([
          req(PayoutStatus.approved, 'Болд', 1),
          req(PayoutStatus.rejected, 'Өөр хүн', 9),
        ]),
        'БОЛД',
      );
      expect(
          cardHolderName([req(PayoutStatus.rejected, 'Өөр хүн', 9)]), isNull);
    });

    test('requests without a name are skipped', () {
      expect(
        cardHolderName([
          req(PayoutStatus.approved, 'Сараа', 1),
          req(PayoutStatus.pending, null, 3),
        ]),
        'САРАА',
      );
    });
  });

  group('isBeforeFirstPayout', () {
    PayoutRequest req(PayoutStatus status) => PayoutRequest(
          id: 1,
          amount: 2000,
          bank: 'Khan Bank',
          status: status,
          requestedAt: DateTime(2026, 10, 14),
        );

    test('a new, unverified viewer is before the first payout', () {
      expect(isBeforeFirstPayout(isVerified: false, payouts: const []), isTrue);
    });

    /// Regression (2026-10-14): the notice came back after the first payout.
    test('not any more once a request is waiting or was paid', () {
      expect(
        isBeforeFirstPayout(
            isVerified: false, payouts: [req(PayoutStatus.pending)]),
        isFalse,
      );
      expect(
        isBeforeFirstPayout(
            isVerified: false, payouts: [req(PayoutStatus.approved)]),
        isFalse,
      );
    });

    test('a verified viewer never is', () {
      expect(isBeforeFirstPayout(isVerified: true, payouts: const []), isFalse);
    });

    test('only rejected requests keep it: the check happens again', () {
      expect(
        isBeforeFirstPayout(
            isVerified: false, payouts: [req(PayoutStatus.rejected)]),
        isTrue,
      );
    });
  });

  group('banks', () {
    test('same list and default as before', () {
      expect(kPayoutBanks, [
        'Khan Bank',
        'Golomt Bank',
        'TDB',
        'Xac Bank',
        'State Bank',
        'M Bank',
        'Capitron Bank',
      ]);
      expect(kDefaultPayoutBank, 'Khan Bank');
      expect(kPayoutBanks, contains(kDefaultPayoutBank));
    });

    test('every bank has its own logo file under assets/banks/', () {
      expect(kBankLogoAssets.keys, unorderedEquals(kPayoutBanks));
      for (final path in kBankLogoAssets.values) {
        expect(path, startsWith('assets/banks/'));
      }
      expect(kBankLogoAssets.values.toSet(), hasLength(kPayoutBanks.length));
    });

    // BankLogo draws the file edge to edge, so a raw download (odd size,
    // transparent margins) would look smaller or clipped next to the others.
    test('every logo file is a 256 px opaque square', () {
      for (final path in kBankLogoAssets.values) {
        final bytes = File(path).readAsBytesSync();
        final header = ByteData.sublistView(bytes, 16, 26);
        final width = header.getUint32(0);
        final height = header.getUint32(4);
        const rgbNoAlpha = 2;
        expect((width, height), (256, 256), reason: path);
        expect(header.getUint8(9), rgbNoAlpha, reason: '$path has alpha');
      }
    });
  });

  group('validators keep the original rules', () {
    test('amount: at least 1,000', () {
      expect(validatePayoutAmount(null), 'Хамгийн бага дүн: 1,000 ₮');
      expect(validatePayoutAmount(''), isNotNull);
      expect(validatePayoutAmount('999'), isNotNull);
      expect(validatePayoutAmount('1000'), isNull);
      expect(validatePayoutAmount('2000'), isNull);
      expect(validatePayoutAmount('12,500'), isNull);
      expect(validatePayoutAmount('999'), isNotNull);
    });

    test('account number: 8 or more characters', () {
      expect(validateAccountNumber(null), isNotNull);
      expect(validateAccountNumber('1234567'), isNotNull);
      expect(validateAccountNumber('12345678'), isNull);
      expect(validateAccountNumber('1234567890123'), isNull);
    });

    test('account name: 3 or more non-blank characters', () {
      expect(validateAccountName(null), isNotNull);
      expect(validateAccountName('  аб  '), isNotNull);
      expect(validateAccountName('Бат'), isNull);
    });
  });
}
