import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  final _storage = const FlutterSecureStorage();

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

  Future<void> logout() async {
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
      final body = res.data!;
      await _saveToken(body['token'] as String);
      return AppUser.fromJson(body['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e, 'Нэвтрэхэд алдаа гарлаа');
    }
  }

  /// POST /auth/register/viewer
  Future<AppUser> register({
    required String phone,
    required String password,
    required Gender gender,
    required DateTime birthDate,
    required String city,
    String? district,
  }) async {
    try {
      final res = await ApiService.instance.dio.post<Map<String, dynamic>>(
        '/auth/register/viewer',
        data: {
          'phoneNumber': phone,
          'password': password,
          'gender': gender.name.toUpperCase(),
          'birthDate':
              '${birthDate.year.toString().padLeft(4, '0')}-'
              '${birthDate.month.toString().padLeft(2, '0')}-'
              '${birthDate.day.toString().padLeft(2, '0')}',
          'city': city,
          if (district != null) 'district': district,
        },
      );
      final body = res.data!;
      await _saveToken(body['token'] as String);
      return AppUser.fromJson(body['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e, 'Бүртгүүлэхэд алдаа гарлаа');
    }
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
      message = 'Сервертэй холбогдож чадсангүй';
    }
    return AuthException(status, message);
  }
}
