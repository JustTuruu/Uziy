import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show
        defaultTargetPlatform,
        kDebugMode,
        kReleaseMode,
        TargetPlatform,
        kIsWeb,
        debugPrint;

import 'api_log.dart';

/// The only scheme a release build may talk to the backend over.
const String kReleaseApiScheme = 'https';

/// Whether the app may use [url] as its API base. Release builds carry the
/// JWT, passwords and bank details, so they need https to a real host;
/// debug and profile builds may use plain http (the local backend at
/// http://localhost:8080 or http://<LAN IP>:8080 on a real phone).
bool isAllowedBaseUrl(String url, {required bool release}) {
  if (!release) return true;
  final uri = Uri.tryParse(url);
  return uri != null && uri.scheme == kReleaseApiScheme && uri.host.isNotEmpty;
}

/// [url] when [isAllowedBaseUrl], otherwise a [StateError] — a release
/// build without an https `API_BASE_URL` must stop at launch instead of
/// silently sending everything in clear text.
String requireAllowedBaseUrl(String url, {required bool release}) {
  if (isAllowedBaseUrl(url, release: release)) return url;
  throw StateError(
    'Release builds need an https API base URL, got "$url". '
    'Build with --dart-define=API_BASE_URL=https://<api host>.',
  );
}

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
        baseUrl: requireAllowedBaseUrl(defaultBaseUrl(), release: kReleaseMode),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        headers: const {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
        // Never throw on 4xx/5xx — controllers decide how to handle status.
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    // Verbose logging in debug builds so failures aren't invisible; secrets
    // in bodies and query strings are masked (api_log.dart).
    if (kDebugMode) {
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint(
              '[api] → ${options.method} ${redactUriForLog(options.uri)}'
              '${options.data != null ? "  body=${redactForLog(options.data)}" : ""}',
            );
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
              '[api] ← ${response.statusCode} '
              '${redactUriForLog(response.requestOptions.uri)}',
            );
            handler.next(response);
          },
          onError: (err, handler) {
            debugPrint(
              '[api] ✗ ${err.type} ${redactUriForLog(err.requestOptions.uri)}'
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

  /// Builds the client now, so a release build with a non-https base URL
  /// fails at launch (see [requireAllowedBaseUrl]), not at the first call.
  void ensureConfigured() => dio;

  /// Point the client at a different host at runtime (e.g. staging).
  void setBaseUrl(String url) {
    dio.options.baseUrl = requireAllowedBaseUrl(url, release: kReleaseMode);
  }

  void setAuthToken(String? token) {
    if (token == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }
}
