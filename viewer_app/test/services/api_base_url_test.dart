import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/api_service.dart';

void main() {
  group('isAllowedBaseUrl', () {
    test('debug and profile builds may use the local http backend', () {
      for (final url in [
        'http://localhost:8080',
        'http://10.0.2.2:8080',
        'http://192.168.1.20:8080',
      ]) {
        expect(isAllowedBaseUrl(url, release: false), isTrue, reason: url);
      }
    });

    test('a release build accepts only https to a real host', () {
      expect(isAllowedBaseUrl('https://api.uziy.mn', release: true), isTrue);
      expect(
        isAllowedBaseUrl('HTTPS://api.uziy.mn/v1', release: true),
        isTrue,
      );
    });

    test('a release build refuses http, other schemes and junk', () {
      for (final url in [
        'http://localhost:8080',
        'http://10.0.2.2:8080',
        'http://api.uziy.mn',
        'ftp://api.uziy.mn',
        'https://',
        'api.uziy.mn',
        '',
      ]) {
        expect(isAllowedBaseUrl(url, release: true), isFalse, reason: url);
      }
    });
  });

  group('requireAllowedBaseUrl', () {
    test('returns an allowed url unchanged', () {
      expect(
        requireAllowedBaseUrl('https://api.uziy.mn', release: true),
        'https://api.uziy.mn',
      );
      expect(
        requireAllowedBaseUrl('http://localhost:8080', release: false),
        'http://localhost:8080',
      );
    });

    test('a release build with an http url fails fast and says how to fix it',
        () {
      expect(
        () => requireAllowedBaseUrl('http://localhost:8080', release: true),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('API_BASE_URL=https://'),
          ),
        ),
      );
    });
  });

  test('tests (a debug build) still get the local default', () {
    expect(ApiService.defaultBaseUrl(), startsWith('http://'));
    ApiService.instance.ensureConfigured();
    expect(
        ApiService.instance.dio.options.baseUrl, ApiService.defaultBaseUrl());
  });
}
