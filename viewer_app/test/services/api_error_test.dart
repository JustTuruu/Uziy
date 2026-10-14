import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/api_error.dart';

const _cyrillic = r'[А-Яа-яӨөҮүЁё]';

void main() {
  group('apiErrorMessage', () {
    test("the backend's own message wins over everything", () {
      expect(
        apiErrorMessage(
          status: 401,
          body: {'message': 'Утасны дугаар эсвэл нууц үг буруу байна'},
          fallback: 'fb',
          byStatus: {401: 'other'},
        ),
        'Утасны дугаар эсвэл нууц үг буруу байна',
      );
    });

    test('a blank backend message is ignored', () {
      expect(
        apiErrorMessage(status: 400, body: {'message': '  '}, fallback: 'fb'),
        'fb',
      );
    });

    test('no connection never mentions localhost or a technical detail', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
      ]) {
        final m = apiErrorMessage(status: 0, type: type, fallback: 'fb');
        expect(m, kNoConnection);
        expect(m, isNot(contains('localhost')));
      }
    });

    test('timeouts ask to try again', () {
      expect(
        apiErrorMessage(
            status: 0, type: DioExceptionType.receiveTimeout, fallback: 'fb'),
        kTimeout,
      );
    });

    test('a per-call wording beats the general one', () {
      expect(
        apiErrorMessage(
            status: 401, fallback: 'fb', byStatus: {401: kWrongCredentials}),
        kWrongCredentials,
      );
    });

    test('general sentences for 401/403, 429 and 5xx; otherwise the fallback',
        () {
      expect(apiErrorMessage(status: 401, fallback: 'fb'), kSignInAgain);
      expect(apiErrorMessage(status: 403, fallback: 'fb'), kSignInAgain);
      expect(apiErrorMessage(status: 429, fallback: 'fb'), kTooManyRequests);
      expect(apiErrorMessage(status: 503, fallback: 'fb'), kServerError);
      expect(apiErrorMessage(status: 404, fallback: 'fb'), 'fb');
    });

    test(
        "Spring's English body without a message (the old 403) is not shown raw",
        () {
      expect(
        apiErrorMessage(
          status: 403,
          body: {'status': 403, 'error': 'Forbidden'},
          fallback: 'fb',
        ),
        kSignInAgain,
      );
    });

    test('every shared sentence is Mongolian', () {
      for (final m in [
        kNoConnection,
        kTimeout,
        kSignInAgain,
        kWrongCredentials,
        kTooManyRequests,
        kServerError,
        kUnexpectedError,
      ]) {
        expect(m, matches(_cyrillic), reason: m);
        expect(m, isNot(matches(r'[A-Za-z]')), reason: m);
      }
    });
  });
}
