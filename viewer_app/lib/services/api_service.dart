import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

/// Thin Dio wrapper. Base URL is chosen at construction time.
///
/// Dev defaults:
/// - iOS Simulator + macOS + web  → http://localhost:8080
/// - Android Emulator             → http://10.0.2.2:8080 (special host that
///                                  routes to the host machine's localhost)
/// - Physical device              → override with `--dart-define=API_BASE_URL=…`
///                                  or set ApiService.instance.setBaseUrl(url).
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static String defaultBaseUrl() {
    // Compile-time override takes precedence.
    const overriden = String.fromEnvironment('API_BASE_URL');
    if (overriden.isNotEmpty) return overriden;

    if (kIsWeb) return 'http://localhost:8080';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: defaultBaseUrl(),
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {'Content-Type': 'application/json'},
      // The backend returns JSON; let Dio parse it automatically.
      responseType: ResponseType.json,
    ),
  );

  /// Point the client at a different host at runtime (e.g. staging).
  void setBaseUrl(String url) {
    dio.options.baseUrl = url;
  }

  void setAuthToken(String? token) {
    if (token == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }
}
