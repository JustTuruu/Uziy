import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/phone_verification.dart';
import '../models/user.dart';
import 'api_service.dart';

/// One-shot error thrown by AuthService when the backend returns 4xx.
/// UI layer catches this to show a friendly localized message.
class AuthException implements Exception {
  final int statusCode;
  final String message;
  AuthException(this.statusCode, this.message);

  @override
  String toString() => 'AuthException($statusCode): $message';
}

/// Why a one-time code is asked for; [wire] is the backend's `OtpPurpose`.
/// Registration does not use codes: it proves the phone by SMS (verify.mn).
enum OtpPurpose {
  passwordReset('PASSWORD_RESET');

  const OtpPurpose(this.wire);
  final String wire;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  final _storage = const FlutterSecureStorage();

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
    await _storage.delete(key: _tokenKey);
    ApiService.instance.setAuthToken(null);
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
      _throwIfNotOk(res, fallback: 'Нэвтрэхэд алдаа гарлаа');
      final body = res.data!;
      await _saveToken(body['token'] as String);
      return AppUser.fromJson(body['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e, 'Нэвтрэхэд алдаа гарлаа');
    }
  }

  /// POST /auth/register/viewer — [verificationId] is a confirmed check
  /// from [startPhoneVerification].
  Future<AppUser> register({
    required String phone,
    required String password,
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

  /// POST /auth/phone-verifications — opens a check of [phone]: the viewer
  /// must text the returned code from it. 409 for a taken phone, 429 when
  /// asked again too soon.
  Future<PhoneVerification> startPhoneVerification(String phone) async {
    const fallback = 'Баталгаажуулалт эхлүүлж чадсангүй';
    try {
      final res = await ApiService.instance.dio.post<dynamic>(
        '/auth/phone-verifications',
        data: {'phoneNumber': phone},
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

  /// POST /auth/otp/request — texts a 6-digit code to [phone]; answers 429
  /// when asked again too soon.
  Future<void> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    const fallback = 'Код илгээж чадсангүй';
    try {
      final res = await ApiService.instance.dio.post<dynamic>(
        '/auth/otp/request',
        data: {'phoneNumber': phone, 'purpose': purpose.wire},
      );
      _throwIfNotOk(res, fallback: fallback);
    } on DioException catch (e) {
      throw _mapDioError(e, fallback);
    }
  }

  /// POST /auth/password/reset — sets a new password using a code from
  /// [requestOtp] (purpose passwordReset).
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    const fallback = 'Нууц үг шинэчилж чадсангүй';
    try {
      final res = await ApiService.instance.dio.post<dynamic>(
        '/auth/password/reset',
        data: {'phoneNumber': phone, 'code': code, 'newPassword': newPassword},
      );
      _throwIfNotOk(res, fallback: fallback);
    } on DioException catch (e) {
      throw _mapDioError(e, fallback);
    }
  }

  /// Dio's validateStatus is set to `< 500`, so 4xx responses come back
  /// through the normal `res` path instead of throwing. Convert them
  /// into an AuthException so the UI layer only has one code path.
  void _throwIfNotOk(Response<dynamic> res, {required String fallback}) {
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) return;
    final data = res.data;
    String message = fallback;
    if (data is Map<String, dynamic> && data['message'] is String) {
      message = data['message'] as String;
    } else if (code == 401) {
      message = 'Утас эсвэл нууц үг буруу байна';
    } else if (code == 409) {
      message = 'Энэ утас аль хэдийн бүртгэлтэй байна';
    }
    throw AuthException(code, message);
  }

  AuthException _mapDioError(DioException e, String fallback) {
    final status = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    String message = fallback;
    if (data is Map<String, dynamic> && data['message'] is String) {
      message = data['message'] as String;
    } else if (status == 401) {
      message = 'Утас эсвэл нууц үг буруу байна';
    } else if (status == 409) {
      message = 'Энэ утас аль хэдийн бүртгэлтэй байна';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      message =
          'Сервертэй холбогдож чадсангүй. Backend ажиллаж байгаа эсэхийг шалгана уу '
          '(http://localhost:8080).';
    } else if (e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      message = 'Хүсэлт удлаа. Дахин оролдоно уу.';
    } else if (e.error != null) {
      message = 'Алдаа: ${e.error}';
    }
    return AuthException(status, message);
  }
}
