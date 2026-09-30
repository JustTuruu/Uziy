/// Formatting helpers shared by every screen.
///
/// All functions are pure (no BuildContext, no locale lookups), so the output
/// is identical on every device and easy to unit test.
library;

/// The tögrög sign.
const String tugrikSymbol = '₮';

/// Groups an integer's digits in thousands with ',' — `3400` -> `3,400`.
/// Negative values keep a leading '-'.
String formatGrouped(int value) {
  // Strip the sign from the string rather than calling `abs()`: the most
  // negative 64-bit int has no positive counterpart (`abs()` overflows).
  final raw = value.toString();
  final digits = value < 0 ? raw.substring(1) : raw;
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return value < 0 ? '-$buf' : buf.toString();
}

/// Money in tögrög: rounds to the nearest whole tögrög (half away from zero)
/// and groups thousands with ','.
///
/// * `formatTugrik(3400)` -> `'3,400 ₮'`
/// * `formatTugrik(700, withSign: true)` -> `'+700 ₮'`
/// * `formatTugrik(-2000)` -> `'-2,000 ₮'` (ASCII hyphen-minus)
/// * `formatTugrik(0, withSign: true)` -> `'0 ₮'` (zero never gets a sign)
/// * NaN / infinity -> `'0 ₮'`
String formatTugrik(num value, {bool withSign = false}) {
  final rounded = value.isFinite ? value.round() : 0;
  final grouped = formatGrouped(rounded);
  final unsigned = rounded < 0 ? grouped.substring(1) : grouped;
  final sign = rounded < 0
      ? '-'
      : (withSign && rounded > 0)
          ? '+'
          : '';
  return '$sign$unsigned $tugrikSymbol';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Short human duration for chips and labels.
///
/// Format (documented contract):
/// * under a minute: `'<s> сек'` — `45` -> `'45 сек'`, `0` -> `'0 сек'`
/// * one minute or more: `'m:ss'` — `90` -> `'1:30'`, `120` -> `'2:00'`
/// * one hour or more: `'h:mm:ss'` — `3725` -> `'1:02:05'`
/// * negative input is treated as 0.
String formatDurationShort(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  if (s < 60) return '$s сек';
  return formatClock(s);
}

/// Player-style clock, always with minutes: `0` -> `'0:00'`, `45` -> `'0:45'`,
/// `90` -> `'1:30'`, `3725` -> `'1:02:05'`.
///
/// Fractional input is truncated toward zero (so for a *remaining-time*
/// countdown, pass `remaining.ceil()` to avoid showing `0:00` too early).
/// Negative / non-finite input is treated as 0.
String formatClock(num seconds) {
  final total = (seconds.isFinite && seconds > 0) ? seconds.truncate() : 0;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final sec = total % 60;
  if (h > 0) return '$h:${_two(m)}:${_two(sec)}';
  return '$m:${_two(sec)}';
}

final RegExp _phoneSeparators = RegExp(r'[\s\-().]');
final RegExp _eightDigits = RegExp(r'^\d{8}$');
final RegExp _withCountryCode = RegExp(r'^\+?976\d{8}$');

/// Mongolian phone number for display: `'88778899'` -> `'+976 8877 8899'`.
///
/// Also accepts the number already carrying the country code
/// (`'+97688778899'`, `'976 8877 8899'`). Anything that is not exactly an
/// 8-digit Mongolian number is returned unchanged.
String formatPhoneMn(String phone) {
  final compact = phone.trim().replaceAll(_phoneSeparators, '');
  String? local;
  if (_eightDigits.hasMatch(compact)) {
    local = compact;
  } else if (_withCountryCode.hasMatch(compact)) {
    local = compact.substring(compact.length - 8);
  }
  if (local == null) return phone;
  return '+976 ${local.substring(0, 4)} ${local.substring(4)}';
}

final RegExp _firstLetterOrDigit = RegExp(r'[\p{L}\p{N}]\p{M}*', unicode: true);

/// First letter (or digit) of [text], upper-cased — for avatars and
/// generated campaign art. Leading quotes, brackets, symbols and emoji are
/// skipped, which matters for Mongolian company names written in quotes.
///
/// * `'MobiCom'` -> `'M'`, `'  голомт'` -> `'Г'`, `'үзье'` -> `'Ү'`
/// * `'«Хаан банк»'` -> `'Х'`, `'"Голомт" банк'` -> `'Г'`
///
/// Returns [fallback] when [text] is null, blank, or has no letter/digit.
String monogramOf(String? text, {String fallback = 'U'}) {
  final match = _firstLetterOrDigit.firstMatch(text ?? '');
  if (match == null) return fallback;
  return match.group(0)!.toUpperCase();
}
