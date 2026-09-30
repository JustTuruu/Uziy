/// Pure wallet / payout helpers. No BuildContext, no router, no network, so
/// everything here is unit-testable in isolation.
library;

import 'package:flutter/services.dart' show TextEditingValue, TextSelection;

/// Smallest payout a viewer can request, in tögrög. The wallet's
/// "Мөнгө татах" button stays disabled below it and the payout form rejects
/// smaller amounts.
const int kPayoutMinimum = 1000;

/// Quick-pick amounts offered above the payout amount field.
const List<int> kQuickPayoutAmounts = [1000, 2000, 5000, 10000];

/// Banks a viewer can cash out to. The first one is the default selection.
const List<String> kPayoutBanks = [
  'Khan Bank',
  'Golomt Bank',
  'TDB',
  'Xac Bank',
  'State Bank',
  'M Bank',
  'Capitron Bank',
];

/// Bank preselected on the payout form.
const String kDefaultPayoutBank = 'Khan Bank';

/// Where a balance stands relative to the payout minimum.
class PayoutProgress {
  const PayoutProgress({
    required this.fraction,
    required this.remaining,
    required this.minimum,
  });

  /// Share of the minimum already collected, clamped to 0..1.
  final double fraction;

  /// Whole tögrög still missing before a payout is allowed. Never negative,
  /// and never 0 while the balance is still below the minimum (a balance of
  /// 999.6 is 1 ₮ short, not "0 ₮ short").
  final int remaining;

  /// The minimum this was computed against.
  final int minimum;

  /// True once the balance has reached the minimum.
  bool get reached => remaining == 0;

  @override
  bool operator ==(Object other) =>
      other is PayoutProgress &&
      other.fraction == fraction &&
      other.remaining == remaining &&
      other.minimum == minimum;

  @override
  int get hashCode => Object.hash(fraction, remaining, minimum);

  @override
  String toString() =>
      'PayoutProgress(fraction: $fraction, remaining: $remaining, '
      'minimum: $minimum)';
}

/// Progress of [balance] toward the payout [minimum].
///
/// * `payoutProgress(0)` -> fraction 0, remaining 1000
/// * `payoutProgress(400)` -> fraction 0.4, remaining 600
/// * `payoutProgress(1000)` / `payoutProgress(5000)` -> fraction 1, remaining 0
/// * negative / NaN / infinite balances count as 0
/// * a non-positive [minimum] is always reached
PayoutProgress payoutProgress(num balance, {int minimum = kPayoutMinimum}) {
  if (minimum <= 0) {
    return PayoutProgress(fraction: 1, remaining: 0, minimum: minimum);
  }
  final b = (balance.isFinite && balance > 0) ? balance.toDouble() : 0.0;
  if (b >= minimum) {
    return PayoutProgress(fraction: 1, remaining: 0, minimum: minimum);
  }
  final missing = (minimum - b).ceil();
  return PayoutProgress(
    fraction: (b / minimum).clamp(0.0, 1.0),
    remaining: missing < 1 ? 1 : missing,
    minimum: minimum,
  );
}

/// Whether the wallet may open the payout form: the profile has loaded
/// ([balance] is non-null) and the balance is at least [minimum].
bool canRequestPayout(num? balance, {int minimum = kPayoutMinimum}) =>
    balance != null && balance >= minimum;

/// The field value a quick-amount chip writes: plain digits (the form parses
/// the text with `double.parse`, so no grouping), caret at the end.
TextEditingValue quickAmountValue(int amount) {
  final text = amount.toString();
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}

/// The quick amount matching the amount field's [text], or null when the
/// field holds something else (used to highlight the active chip).
int? selectedQuickAmount(
  String text, {
  List<int> amounts = kQuickPayoutAmounts,
}) {
  final value = int.tryParse(text.trim());
  if (value == null) return null;
  return amounts.contains(value) ? value : null;
}

// --- Payout form validators -------------------------------------------------
// The rules are unchanged from the original form; only the account-number,
// name and ID messages were reworded from bare field names into guidance.

/// Amount: whole tögrög, at least [kPayoutMinimum].
String? validatePayoutAmount(String? value) {
  final n = int.tryParse(value ?? '') ?? 0;
  if (n < kPayoutMinimum) return 'Хамгийн бага дүн: 1,000 ₮';
  return null;
}

/// Account number: at least 8 characters (the field only accepts digits).
String? validateAccountNumber(String? value) =>
    (value == null || value.length < 8)
        ? 'Дансны дугаар дор хаяж 8 оронтой байна'
        : null;

/// Account holder name: at least 3 non-blank characters.
String? validateAccountName(String? value) =>
    (value == null || value.trim().length < 3)
        ? 'Дансны эзэмшигчийн нэрийг бүтэн оруулна уу'
        : null;

/// National ID: exactly 10 characters (e.g. АА99999999).
String? validateNationalId(String? value) =>
    (value == null || value.length != 10)
        ? 'Регистрийн дугаар 10 тэмдэгттэй байна'
        : null;
