/// Pure helpers for the profile tab: display formatting, the load / logout
/// sequencing, request coalescing and a per-session cache.
///
/// No Flutter widgets and no router import, so they are cheap to unit test
/// and safe to use from any widget file. ProfileScreen only turns the
/// results into navigation and setState.
library;

import '../../models/user.dart';
import '../../services/viewer_service.dart' show ApiException;
import '../../utils/format.dart';

/// Shown wherever a profile value is missing.
const String kEmptyValue = '—';

/// Copy used by the verification badge and hint.
const String kVerifiedLabel = 'Баталгаажсан';
const String kUnverifiedLabel = 'Баталгаажаагүй';
const String kUnverifiedHint = 'Анхны мөнгө татахад баталгаажна';

/// Snackbar copy.
const String kComingSoon = 'Удахгүй';
const String kLogoutFailed = 'Гарахад алдаа гарлаа. Дахин оролдоно уу.';

/// Load error for anything that is not an [ApiException] (no network,
/// timeout, unexpected payload).
const String kGenericLoadError = 'Сервертэй холбогдож чадсангүй';

/// 'Эрэгтэй' / 'Эмэгтэй', or [kEmptyValue] when unknown.
String genderLabel(Gender? gender) => switch (gender) {
      Gender.male => 'Эрэгтэй',
      Gender.female => 'Эмэгтэй',
      null => kEmptyValue,
    };

/// Trimmed [value], or [kEmptyValue] when it is null or blank.
String displayOrDash(String? value) {
  final v = value?.trim() ?? '';
  return v.isEmpty ? kEmptyValue : v;
}

/// Age as digits ('24'), or [kEmptyValue] when unknown or negative.
String ageLabel(int? age) => (age == null || age < 0) ? kEmptyValue : '$age';

/// Phone formatted for display ('+976 8877 8899'), or [kEmptyValue].
String phoneLabel(String? phone) {
  final p = phone?.trim() ?? '';
  return p.isEmpty ? kEmptyValue : formatPhoneMn(p);
}

/// Screen-reader label of the balance tile. When it opens the wallet it
/// reads like the home balance pill ('Хэтэвч, үлдэгдэл 3,400 ₮').
String balanceSemantics(num balance, {bool opensWallet = false}) {
  final amount = formatTugrik(balance);
  return opensWallet ? 'Хэтэвч, үлдэгдэл $amount' : 'Үлдэгдэл: $amount';
}

/// Screen-reader label of a stat tile: the label first, then the value
/// ('Нас: 24'), which is the order people expect to hear it in.
String statSemantics(String label, String value) => '$label: $value';

/// Whether the retry action of the load-error banner should sit on its own
/// line under the message instead of beside it. Beside it, a narrow banner
/// (small phone) or large OS text leaves the message only a sliver of width.
bool stackRetryAction({required double width, required double textScale}) =>
    width < kStackRetryBelowWidth || textScale > kStackRetryAboveTextScale;

const double kStackRetryBelowWidth = 340;
const double kStackRetryAboveTextScale = 1.15;

/// Which personal-info field a [ProfileField] describes. The widget layer
/// maps it to an icon.
enum ProfileFieldKind { gender, age, city, district }

/// One label/value row of the 'Хувийн мэдээлэл' card.
class ProfileField {
  const ProfileField(this.kind, this.label, this.value);

  final ProfileFieldKind kind;
  final String label;

  /// Already formatted; [kEmptyValue] when missing.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is ProfileField &&
      other.kind == kind &&
      other.label == label &&
      other.value == value;

  @override
  int get hashCode => Object.hash(kind, label, value);

  @override
  String toString() => 'ProfileField($kind, $label, $value)';
}

/// Rows for the 'Хувийн мэдээлэл' card: Хүйс, Нас, Хот always (with
/// [kEmptyValue] fallbacks), and Дүүрэг only when the user has one.
List<ProfileField> personalFields(AppUser user) {
  final district = user.district?.trim() ?? '';
  return [
    ProfileField(ProfileFieldKind.gender, 'Хүйс', genderLabel(user.gender)),
    ProfileField(ProfileFieldKind.age, 'Нас', ageLabel(user.age)),
    ProfileField(ProfileFieldKind.city, 'Хот', displayOrDash(user.city)),
    if (district.isNotEmpty)
      ProfileField(ProfileFieldKind.district, 'Дүүрэг', district),
  ];
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

/// True for an expired or revoked session (HTTP 401 / 403): the stored
/// token must be cleared and the user sent back to login.
bool isSessionExpired(Object error) =>
    error is ApiException &&
    (error.statusCode == 401 || error.statusCode == 403);

/// User-facing message for a failed profile load: the server's own message
/// for an [ApiException], [kGenericLoadError] for anything else.
String loadErrorMessage(Object error) =>
    error is ApiException ? error.message : kGenericLoadError;

/// Outcome of [loadProfile].
sealed class ProfileLoadResult {
  const ProfileLoadResult();
}

/// GET /viewer/me succeeded.
final class ProfileLoaded extends ProfileLoadResult {
  const ProfileLoaded(this.user);
  final AppUser user;
}

/// The request failed; [message] is ready to show in the error banner.
final class ProfileLoadFailed extends ProfileLoadResult {
  const ProfileLoadFailed(this.message);
  final String message;
}

/// 401 / 403: the token was cleared (or clearing it failed). Either way
/// the screen goes to login.
final class ProfileSessionExpired extends ProfileLoadResult {
  const ProfileSessionExpired();
}

/// Fetches the profile and classifies the result. Never throws.
///
/// On 401 / 403 it calls [clearToken]. If that throws too (secure storage
/// unavailable), the result is still [ProfileSessionExpired]: leaving the
/// user on a skeleton or an unhandled error would be worse than sending
/// them to login with a stale token that the server rejects anyway.
Future<ProfileLoadResult> loadProfile({
  required Future<AppUser> Function() fetch,
  required Future<void> Function() clearToken,
}) async {
  try {
    return ProfileLoaded(await fetch());
  } catch (e) {
    if (!isSessionExpired(e)) return ProfileLoadFailed(loadErrorMessage(e));
    try {
      await clearToken();
    } catch (_) {
      // See the doc comment: go to login regardless.
    }
    return const ProfileSessionExpired();
  }
}

// ---------------------------------------------------------------------------
// Logout
// ---------------------------------------------------------------------------

/// Outcome of [runLogout].
enum LogoutResult {
  /// The user dismissed the sheet or tapped 'Болих'; nothing was cleared.
  cancelled,

  /// The token is cleared; navigate to login.
  done,

  /// Clearing the token failed; stay on the screen and say so.
  failed,
}

/// Logout sequencing: ask first, then clear the stored token, and only
/// report [LogoutResult.done] once it is really gone, so the next launch
/// cannot silently sign the user back in.
Future<LogoutResult> runLogout({
  required Future<bool> Function() confirm,
  required Future<void> Function() clearToken,
}) async {
  if (!await confirm()) return LogoutResult.cancelled;
  try {
    await clearToken();
    return LogoutResult.done;
  } catch (_) {
    return LogoutResult.failed;
  }
}

// ---------------------------------------------------------------------------
// Request plumbing
// ---------------------------------------------------------------------------

/// Coalesces concurrent calls: while a task is running, [run] returns the
/// same future instead of starting another one. Pull-to-refresh and the
/// retry button therefore never race two requests.
class SingleFlight<T> {
  Future<T>? _inflight;

  /// Whether a task is currently running.
  bool get isRunning => _inflight != null;

  Future<T> run(Future<T> Function() task) {
    final running = _inflight;
    if (running != null) return running;
    final future = task().whenComplete(() => _inflight = null);
    _inflight = future;
    return future;
  }
}

/// Remembers one value per signed-in session, so revisiting a tab renders
/// the last data at once while it refreshes in the background.
///
/// [sessionKey] is whatever identifies the session (the auth header). A
/// read with a different or null key returns null, so a new login never
/// sees the previous account's data.
class SessionCache<T extends Object> {
  String? _key;
  T? _value;

  T? read(String? sessionKey) =>
      (sessionKey != null && sessionKey == _key) ? _value : null;

  /// Stores [value] for [sessionKey]. A null key (signed out) clears.
  void write(String? sessionKey, T value) {
    if (sessionKey == null) {
      clear();
      return;
    }
    _key = sessionKey;
    _value = value;
  }

  void clear() {
    _key = null;
    _value = null;
  }
}
