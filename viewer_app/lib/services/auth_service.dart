import 'package:dio/dio.dart';
import '../models/phone_verification.dart';
import '../models/user.dart';
import '../widgets/animated_money.dart';
import 'api_error.dart';
import 'api_service.dart';
import 'secure_store.dart';

/// One-shot error thrown by AuthService when the backend returns 4xx.
/// UI layer catches this to show a friendly localized message.
class AuthException implements Exception {
  final int statusCode;
  final String message;
  AuthException(this.statusCode, this.message);

  @override
  String toString() => 'AuthException($statusCode): $message';
}

/// What a phone check is for; [wire] is the backend's
/// `PhoneVerificationPurpose`. A check is spent only for its own purpose.
enum PhoneCheckPurpose {
  register('REGISTER'),
  passwordReset('PASSWORD_RESET');

  const PhoneCheckPurpose(this.wire);
  final String wire;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';

  /// On login a 401 means the phone or password is wrong, not "sign in
  /// again" (used only if the backend sent no message).
  static const _loginByStatus = {401: kWrongCredentials};
  final _storage = appSecureStorage;

  /// True while a JWT is loaded into the HTTP client (after login,
  /// registration or [restore]); false for a guest. Synchronous on purpose:
  /// the router's redirect cannot await secure storage.
  bool get isSignedIn =>
      ApiService.instance.dio.options.headers['Authorization'] != null;

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      // Secure storage isn't available (e.g. widget tests, first launch on
      // some Android devices). Treat as no token.
      return null;
    }
  }

  Future<void> _saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    ApiService.instance.setAuthToken(token);
  }

  /// Runs before the token is cleared (still authenticated), e.g. to
  /// unregister the push device. Failures are swallowed: logout never blocks.
  Future<void> Function()? onBeforeLogout;

  Future<void> logout() async {
    try {
      await onBeforeLogout?.call();
    } catch (_) {}
    try {
      await _storage.delete(key: _tokenKey);
    } finally {
      // In-memory session state goes even if the keychain write failed.
      ApiService.instance.setAuthToken(null);
      // The next person on this phone must not see the previous balance
      // roll in from the remembered amount.
      MoneyMemory.clear();
    }
  }

  /// Bootstrap on app start — reload the persisted token into Dio's default
  /// headers so subsequent calls are already authenticated.
  Future<void> restore() async {
    final t = await readToken();
    if (t != null) ApiService.instance.setAuthToken(t);
  }

  /// POST /auth/login
  Future<AppUser> login({
    required String phone,
    required String password,
  }) async {
    try {
      final res = await ApiService.instance.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'phoneNumber': phone, 'password': password},
      );
      _throwIfNotOk(res,
          fallback: 'Нэвтрэхэд алдаа гарлаа', byStatus: _loginByStatus);
      final body = res.data!;
      await _saveToken(body['token'] as String);
      return AppUser.fromJson(body['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e, 'Нэвтрэхэд алдаа гарлаа', byStatus: _loginByStatus);
    }
  }

  /// POST /auth/register/viewer — [verificationId] is a confirmed check
  /// from [startPhoneVerification].
  Future<AppUser> register({
    required String phone,
    required String password,
    required String lastName,
    required String firstName,
    required Gender gender,
    required DateTime birthDate,
    required String city,
    String? district,
    required String verificationId,
  }) async {
    try {
      final res = await ApiService.instance.dio.post<Map<String, dynamic>>(
        '/auth/register/viewer',
        data: {
          'phoneNumber': phone,
          'password': password,
          'lastName': lastName,
          'firstName': firstName,
          'gender': gender.name.toUpperCase(),
          'birthDate': '${birthDate.year.toString().padLeft(4, '0')}-'
              '${birthDate.month.toString().padLeft(2, '0')}-'
              '${birthDate.day.toString().padLeft(2, '0')}',
          'city': city,
          if (district != null) 'district': district,
          'verificationId': verificationId,
        },
      );
      _throwIfNotOk(res, fallback: 'Бүртгүүлэхэд алдаа гарлаа');
      final body = res.data!;
      await _saveToken(body['token'] as String);
      return AppUser.fromJson(body['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e, 'Бүртгүүлэхэд алдаа гарлаа');
    }
  }

  /// POST /auth/phone-verifications — opens a check of [phone] for
  /// [purpose]: the viewer must text the returned code from it. 409 when
  /// registering a taken phone, 404 when resetting a phone with no account,
  /// 429 when asked again too soon.
  Future<PhoneVerification> startPhoneVerification(
    String phone, {
    PhoneCheckPurpose purpose = PhoneCheckPurpose.register,
  }) async {
    const fallback = 'Баталгаажуулалт эхлүүлж чадсангүй';
    try {
      final res = await ApiService.instance.dio.post<dynamic>(
        '/auth/phone-verifications',
        data: {'phoneNumber': phone, 'purpose': purpose.wire},
      );
      _throwIfNotOk(res, fallback: fallback);
      return PhoneVerification.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e, fallback);
    }
  }

  /// GET /auth/phone-verifications/{id} — polled until verified or expired.
  Future<PhoneVerificationState> phoneVerificationState(String id) async {
    const fallback = 'Төлөв шалгаж чадсангүй';
    try {
      final res = await ApiService.instance.dio.get<dynamic>(
        '/auth/phone-verifications/$id',
      );
      _throwIfNotOk(res, fallback: fallback);
      return PhoneVerificationState.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e, fallback);
    }
  }

  /// POST /auth/password/reset — sets a new password for [phone], proved by
  /// the confirmed password-reset check [verificationId]. 400 when the check
  /// is not (or no longer) usable.
  Future<void> resetPassword({
    required String phone,
    required String verificationId,
    required String newPassword,
  }) async {
    const fallback = 'Нууц үг шинэчилж чадсангүй';
    try {
      final res = await ApiService.instance.dio.post<dynamic>(
        '/auth/password/reset',
        data: {
          'phoneNumber': phone,
          'verificationId': verificationId,
          'newPassword': newPassword,
        },
      );
      _throwIfNotOk(res, fallback: fallback);
    } on DioException catch (e) {
      throw _mapDioError(e, fallback);
    }
  }

  /// Dio's validateStatus is set to `< 500`, so 4xx responses come back
  /// through the normal `res` path instead of throwing. Convert them
  /// into an AuthException so the UI layer only has one code path.
  void _throwIfNotOk(
    Response<dynamic> res, {
    required String fallback,
    Map<int, String> byStatus = const {},
  }) {
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) return;
    throw AuthException(
      code,
      apiErrorMessage(
        status: code,
        body: res.data,
        fallback: fallback,
        byStatus: byStatus,
      ),
    );
  }

  AuthException _mapDioError(
    DioException e,
    String fallback, {
    Map<int, String> byStatus = const {},
  }) {
    final status = e.response?.statusCode ?? 0;
    return AuthException(
      status,
      apiErrorMessage(
        status: status,
        body: e.response?.data,
        type: e.type,
        fallback: fallback,
        byStatus: byStatus,
      ),
    );
  }
}
