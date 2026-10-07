/// Pure helpers and copy for the one-time-code screens (no widgets).
library;

/// How long the 'Дахин илгээх' button stays locked after a code is sent.
/// Matches the backend cool-down (OtpServiceImpl.COOLDOWN).
const int kOtpResendSeconds = 60;

const String kOtpTitle = 'Баталгаажуулах код';
const String kOtpConfirmLabel = 'Баталгаажуулах';
const String kOtpResendLabel = 'Дахин илгээх';
const String kOtpResent = 'Код дахин илгээлээ';
const String kOtpIncomplete = '6 оронтой кодоо оруулна уу';

/// 'm:ss' of [seconds] (negative counts as 0): `45` -> `0:45`, `60` -> `1:00`.
String formatCountdown(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final mm = s ~/ 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

/// Text of the resend button: plain while it can be used, with the time
/// left while it is locked.
String resendLabel(int secondsLeft) => secondsLeft <= 0
    ? kOtpResendLabel
    : '$kOtpResendLabel (${formatCountdown(secondsLeft)})';

/// 'Бид +976 8811 2233 дугаарт 6 оронтой код илгээлээ' — [formattedPhone]
/// is already formatted for display.
String otpSubtitle(String formattedPhone) =>
    'Бид $formattedPhone дугаарт 6 оронтой код илгээлээ';

/// True once [code] has all [length] digits.
bool isCompleteCode(String code, {int length = 6}) => code.length == length;
