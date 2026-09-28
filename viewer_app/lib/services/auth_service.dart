import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';
import 'api_service.dart';

/// Handles auth + token persistence. All network calls are stubs — wire to
/// Spring Boot endpoints when they exist.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  final _storage = const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> _saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    ApiService.instance.setAuthToken(token);
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    ApiService.instance.setAuthToken(null);
  }

  /// POST /auth/login
  Future<AppUser> login({
    required String phone,
    required String password,
  }) async {
    // TODO: real call.
    // final res = await ApiService.instance.dio.post('/auth/login',
    //   data: {'phone_number': phone, 'password': password});
    // await _saveToken(res.data['token'] as String);
    // return AppUser.fromJson(res.data['user'] as Map<String, dynamic>);
    throw UnimplementedError('AuthService.login not wired yet');
  }

  /// POST /auth/register
  Future<AppUser> register({
    required String phone,
    required String password,
    required Gender gender,
    required DateTime birthDate,
    required String city,
    String? district,
  }) async {
    // TODO: real call.
    throw UnimplementedError('AuthService.register not wired yet');
  }
}
