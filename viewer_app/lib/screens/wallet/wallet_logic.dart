/// Pure wallet / payout helpers. No BuildContext, no router, no network, so
/// everything here is unit-testable in isolation.
library;

import 'package:flutter/services.dart'
    show TextEditingValue, TextInputFormatter, TextSelection;

import '../../models/payout_request.dart';
import '../../models/view_history_item.dart';
import '../../utils/format.dart';

/// Smallest payout a viewer can request, in tögrög. The wallet's
/// "Мөнгө татах" button stays disabled below it and the payout form rejects
/// smaller amounts.
const int kPayoutMinimum = 1000;

/// Amount the payout form opens with (also one of the quick picks).
const int kDefaultPayoutAmount = 2000;

const String kPayoutAmountLabel = 'Татах дүн';
const String kPayoutAmountHelper =
    'Дүнгээ бичнэ үү, эсвэл доороос сонгоно уу. Хамгийн багадаа 1,000 ₮.';
const String kQuickAmountsLabel = 'Хурдан сонгох';

/// Quick-pick amounts offered under the payout amount field.
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

/// Where each bank's logo is bundled (`assets/banks/`, listed in pubspec).
/// The names above are what the backend stores, so they stay plain strings; a
/// bank without a logo file simply shows its monogram.
const Map<String, String> kBankLogoAssets = {
  'Khan Bank': 'assets/banks/khan_bank.png',
  'Golomt Bank': 'assets/banks/golomt_bank.png',
  'TDB': 'assets/banks/tdb.png',
  'Xac Bank': 'assets/banks/xac_bank.png',
  'State Bank': 'assets/banks/state_bank.png',
  'M Bank': 'assets/banks/m_bank.png',
  'Capitron Bank': 'assets/banks/capitron_bank.png',
};

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

/// Longest amount the field takes (999,999,999 ₮): far above any balance,
/// short enough that a stray paste cannot overflow anything.
const int kPayoutAmountMaxDigits = 9;

/// The whole tögrög typed in the amount field, ignoring the grouping commas
/// (`'12,500'` -> 12500); null when there are no digits.
int? payoutAmountOf(String? text) {
  final digits = (text ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

/// The amount field while the user types: digits only, grouped in thousands
/// (`12500` -> `12,500`), at most [kPayoutAmountMaxDigits] digits and no
/// leading zeros. The caret keeps its place among the digits, so editing in
/// the middle of the number works.
class PayoutAmountFormatter extends TextInputFormatter {
  const PayoutAmountFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final caret = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, newValue.text.length)
        : newValue.text.length;
    var digitsBeforeCaret = _digitCount(newValue.text.substring(0, caret));
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final leadingZeros =
        digits.length - digits.replaceFirst(RegExp(r'^0+'), '').length;
    digits = digits.substring(leadingZeros);
    digitsBeforeCaret =
        (digitsBeforeCaret - leadingZeros).clamp(0, digits.length);
    if (digits.length > kPayoutAmountMaxDigits) {
      digits = digits.substring(0, kPayoutAmountMaxDigits);
      digitsBeforeCaret = digitsBeforeCaret.clamp(0, digits.length);
    }
    final text = digits.isEmpty ? '' : formatGrouped(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: _offsetAfterDigits(text, digitsBeforeCaret),
      ),
    );
  }

  static int _digitCount(String s) =>
      s.replaceAll(RegExp(r'[^0-9]'), '').length;

  /// Position in [text] just after its [count]-th digit.
  static int _offsetAfterDigits(String text, int count) {
    if (count <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      if (_digitCount(text[i]) == 1) seen++;
      if (seen == count) return i + 1;
    }
    return text.length;
  }
}

/// The field value a quick-amount chip writes: the amount grouped like typed
/// text (`5,000`), caret at the end.
TextEditingValue quickAmountValue(int amount) {
  final text = formatGrouped(amount);
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
  final value = payoutAmountOf(text);
  if (value == null) return null;
  return amounts.contains(value) ? value : null;
}

// --- Payout form validators -------------------------------------------------
// The rules are unchanged from the original form; only the account-number,
// name and ID messages were reworded from bare field names into guidance.

/// Amount: whole tögrög, at least [kPayoutMinimum].
String? validatePayoutAmount(String? value) {
  final n = payoutAmountOf(value) ?? 0;
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

/// The phone shown like a card number on the wallet card: only the last four
/// digits, e.g. '•••• 9911'. Anything without four trailing digits shows
/// dots only, so a malformed value never leaks.
String maskedCardNumber(String? phone) {
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  const hidden = '••••';
  if (digits.length < 4) return '$hidden $hidden';
  return '$hidden ${digits.substring(digits.length - 4)}';
}

/// The name printed on the wallet card: the registered нэр + овог in capitals
/// (bank-card style, given name first). Only the name given at registration
/// (owner, 2026-10-21) — never a payout's account holder, which can be someone
/// else's. Null (no name line) for accounts made before names were asked.
String? walletCardName({String? lastName, String? firstName}) {
  final registered = [firstName, lastName]
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(' ');
  return registered.isEmpty ? null : registered.toUpperCase();
}

/// Whether the viewer has not made their first payout yet — the one the
/// admin uses to verify the account. False once they are verified, or once a
/// request is waiting or was paid (they have seen the notice and acted on
/// it). A rejected request alone keeps it true: the check happens again.
bool isBeforeFirstPayout({
  required bool isVerified,
  required List<PayoutRequest> payouts,
}) =>
    !isVerified && payouts.every((p) => p.status == PayoutStatus.rejected);

/// True while any request still waits for the admin — the wallet then
/// checks back regularly so the decision shows up without a manual refresh.
bool hasPendingPayout(List<PayoutRequest> payouts) =>
    payouts.any((p) => p.isPending);

/// Requests that were pending in [before] and are decided in [after]: the
/// decisions that arrived since the last load.
List<PayoutRequest> newlyDecided(
  List<PayoutRequest> before,
  List<PayoutRequest> after,
) {
  final wasPending = {
    for (final p in before)
      if (p.isPending) p.id,
  };
  return [
    for (final p in after)
      if (!p.isPending && wasPending.contains(p.id)) p,
  ];
}

/// One-line news for a decision that just arrived.
String payoutDecisionMessage(PayoutRequest p) => switch (p.status) {
      PayoutStatus.approved =>
        '${formatTugrik(p.amount)} татах хүсэлт тань батлагдлаа',
      PayoutStatus.rejected =>
        '${formatTugrik(p.amount)} татах хүсэлт татгалзагдаж, мөнгө тань хэтэвчинд буцлаа',
      PayoutStatus.pending => '',
    };

// --- Wallet history ----------------------------------------------------------

const String kWalletHistoryTitle = 'Хэтэвчний түүх';
const String kWalletHistoryEmptyTitle = 'Түүх хоосон байна';
const String kWalletHistoryEmptyMessage =
    'Урамшуулал авах, мөнгө татах бүрт энд бүртгэгдэнэ.';
const String kWalletIncomeLabel = 'Нийт орлого';
const String kWalletSpendingLabel = 'Нийт зарлага';

/// Height of the scrolling history box: about five rows, then it scrolls.
const double kWalletHistoryBoxHeight = 360;

/// One line of the wallet history, newest first: money in (a reward) or
/// money out (a payout request).
///
/// Pattern: sealed variants, so every screen that lists them handles both.
sealed class WalletEntry {
  const WalletEntry();
  DateTime get at;
}

class RewardEntry extends WalletEntry {
  const RewardEntry(this.reward);
  final ViewHistoryItem reward;
  @override
  DateTime get at => reward.watchedAt;
}

class PayoutEntry extends WalletEntry {
  const PayoutEntry(this.payout);
  final PayoutRequest payout;
  @override
  DateTime get at => payout.requestedAt;
}

/// Rewards and payout requests merged into one list, newest first.
List<WalletEntry> buildWalletHistory(
  List<ViewHistoryItem> rewards,
  List<PayoutRequest> payouts,
) =>
    [
      for (final r in rewards) RewardEntry(r),
      for (final p in payouts) PayoutEntry(p),
    ]..sort((a, b) => b.at.compareTo(a.at));

/// Which way money moved for one history entry — the icon in front of a row
/// says it at a glance.
enum MoneyFlow {
  /// A reward came into the wallet.
  incoming,

  /// A payout left the wallet (or is on its way to the bank).
  outgoing,

  /// A rejected payout: the money came back.
  returned,
}

/// [MoneyFlow] of a wallet history entry.
MoneyFlow moneyFlowOf(WalletEntry entry) => switch (entry) {
      RewardEntry() => MoneyFlow.incoming,
      PayoutEntry(:final payout) => payout.status == PayoutStatus.rejected
          ? MoneyFlow.returned
          : MoneyFlow.outgoing,
    };

/// Everything the rewards paid in.
double walletIncome(List<ViewHistoryItem> rewards) =>
    rewards.fold(0.0, (sum, r) => sum + r.rewardPaid);

/// Money that left (or is on its way out of) the wallet. A rejected
/// request was refunded, so it does not count.
double walletSpending(List<PayoutRequest> payouts) => payouts
    .where((p) => p.status != PayoutStatus.rejected)
    .fold(0.0, (sum, p) => sum + p.amount);

/// Status line of a payout row.
String payoutEntryStatus(PayoutRequest p) => switch (p.status) {
      PayoutStatus.pending => 'Хянагдаж байна',
      PayoutStatus.approved => 'Дансанд шилжүүлсэн',
      PayoutStatus.rejected => 'Татгалзсан · хэтэвчинд буцсан',
    };

/// Title of a payout row: 'Мөнгө татсан · Khan Bank'.
String payoutEntryTitle(PayoutRequest p) =>
    p.bank.isEmpty ? 'Мөнгө татсан' : 'Мөнгө татсан · ${p.bank}';
