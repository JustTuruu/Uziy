import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/wallet/wallet_logic.dart';

void main() {
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

    test('quickAmountValue writes plain digits with the caret at the end', () {
      final v = quickAmountValue(5000);
      expect(v.text, '5000');
      expect(v.selection.isCollapsed, isTrue);
      expect(v.selection.baseOffset, 4);
      // The form parses the field with double.parse, so no grouping commas.
      expect(double.parse(v.text), 5000);
    });

    test('quickAmountValue text passes the amount validator', () {
      for (final a in kQuickPayoutAmounts) {
        expect(validatePayoutAmount(quickAmountValue(a).text), isNull);
      }
    });

    test('selectedQuickAmount matches exact chip values only', () {
      expect(selectedQuickAmount('2000'), 2000);
      expect(selectedQuickAmount(' 5000 '), 5000);
      expect(selectedQuickAmount('10000'), 10000);
      expect(selectedQuickAmount('2500'), isNull);
      expect(selectedQuickAmount(''), isNull);
      expect(selectedQuickAmount('abc'), isNull);
      expect(selectedQuickAmount('300', amounts: const [300]), 300);
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
  });

  group('validators keep the original rules', () {
    test('amount: at least 1,000', () {
      expect(validatePayoutAmount(null), 'Хамгийн бага дүн: 1,000 ₮');
      expect(validatePayoutAmount(''), isNotNull);
      expect(validatePayoutAmount('999'), isNotNull);
      expect(validatePayoutAmount('1000'), isNull);
      expect(validatePayoutAmount('2000'), isNull);
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

    test('national ID: exactly 10 characters', () {
      expect(validateNationalId(null), isNotNull);
      expect(validateNationalId('АА9999999'), isNotNull);
      expect(validateNationalId('АА99999999'), isNull);
      expect(validateNationalId('АА999999999'), isNotNull);
    });
  });
}
