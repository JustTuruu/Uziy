/// Pure helpers and copy for the phone-verification page (no widgets).
///
/// The viewer proves the phone by texting a code FROM it to verify.mn's
/// short code. Every such SMS costs them 150 ₮, so the page never invites a
/// second one once the first has arrived.
library;

import '../../models/phone_verification.dart';

/// verify.mn asks for at least 3 s between status checks.
const Duration kPhoneVerifyPollInterval = Duration(seconds: 3);

/// Polling goes on this long past `expiresAt` (an SMS sent in the last
/// seconds may still be confirmed) before the page gives up by itself.
const Duration kPhoneVerifyExpiryGrace = Duration(seconds: 10);

const String kPhoneVerifyTitle = 'Утсаа баталгаажуулах';
const String kPhoneVerifySubtitle =
    'Бүртгэлээ дуусгахын тулд өөрийн утаснаасаа нэг SMS илгээнэ үү.';
const String kSendSmsLabel = 'SMS илгээх';
const String kSmsToLabel = 'Хүлээн авах дугаар';
const String kSmsTextLabel = 'Текст';
const String kSmsCostNote =
    'SMS-ийн төлбөр 150₮ (операторын үнэ). Нэг удаа илгээхэд хангалттай.';
const String kWaitingForSms = 'Таны SMS-ийг хүлээж байна…';
const String kCreatingAccount = 'Бүртгэл үүсгэж байна…';
const String kSmsAppFailed =
    'SMS апп нээгдсэнгүй. Дээрх кодыг 144773 дугаарт гараар илгээнэ үү.';
const String kCodeExpiredTitle = 'Кодын хугацаа дууслаа';
const String kCodeExpiredMessage =
    'Хуучин код хүчингүй боллоо. Шинэ код аваад дахин илгээнэ үү.';
const String kNewCodeLabel = 'Шинэ код авах';
const String kNewCodeReady = 'Шинэ код үүслээ. Хуучин кодыг бүү илгээгээрэй.';
const String kRetryLabel = 'Дахин оролдох';

/// What the page is doing right now.
enum PhoneVerifyPhase {
  /// Waiting for the SMS; polling.
  waiting,

  /// The SMS arrived; the account is being created.
  registering,

  /// Time ran out (or the check can no longer be used): a new code is needed.
  expired,

  /// Creating the account failed for another reason; it can be retried.
  failed,
}

/// The phase after a poll answered [status]: [registering] once verified,
/// [expired] when the backend says so or the page's own deadline passed,
/// otherwise still [waiting].
PhoneVerifyPhase phaseAfterPoll(
  PhoneVerificationStatus status, {
  required DateTime expiresAt,
  required DateTime now,
}) {
  switch (status) {
    case PhoneVerificationStatus.verified:
      return PhoneVerifyPhase.registering;
    case PhoneVerificationStatus.expired:
      return PhoneVerifyPhase.expired;
    case PhoneVerificationStatus.pending:
      return isPastDeadline(expiresAt, now)
          ? PhoneVerifyPhase.expired
          : PhoneVerifyPhase.waiting;
  }
}

/// True once [now] is past [expiresAt] plus [kPhoneVerifyExpiryGrace].
bool isPastDeadline(DateTime expiresAt, DateTime now) =>
    now.isAfter(expiresAt.add(kPhoneVerifyExpiryGrace));

/// A failed registration that a retry cannot fix (the check is not, or no
/// longer, usable — HTTP 400) needs a new code instead.
bool needsNewCode(int statusCode) => statusCode == 400;
