import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, TargetPlatform, kIsWeb, debugPrint;

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

  late final Dio dio = _buildDio();

  Dio _buildDio() {
    final client = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl(),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        headers: const {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
        // Never throw on 4xx/5xx — controllers decide how to handle status.
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    // Verbose logging in debug builds so failures aren't invisible.
    if (kDebugMode) {
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint(
              '[api] → ${options.method} ${options.uri}'
              '${options.data != null ? "  body=${options.data}" : ""}',
            );
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
              '[api] ← ${response.statusCode} ${response.requestOptions.uri}',
            );
            handler.next(response);
          },
          onError: (err, handler) {
            debugPrint(
              '[api] ✗ ${err.type} ${err.requestOptions.uri}'
              '  status=${err.response?.statusCode}'
              '  message=${err.message}',
            );
            handler.next(err);
          },
        ),
      );
      debugPrint('[api] initialized with baseUrl=${client.options.baseUrl}');
    }

    return client;
  }

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
