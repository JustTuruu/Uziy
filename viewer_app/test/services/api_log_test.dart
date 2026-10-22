import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/api_log.dart';

void main() {
  group('redactForLog', () {
    test('masks passwords and the bank account, keeps the rest', () {
      expect(
        redactForLog({
          'phoneNumber': '88112233',
          'password': 'secret1',
          'newPassword': 'secret2',
          'accountNumber': '5012345678',
          'accountName': 'БОЛД',
          'amount': 5000,
        }),
        {
          'phoneNumber': '88112233',
          'password': kRedactedValue,
          'newPassword': kRedactedValue,
          'accountNumber': kRedactedValue,
          'accountName': 'БОЛД',
          'amount': 5000,
        },
      );
    });

    test('masks the device token and nested secrets, whatever the case', () {
      expect(
        redactForLog({
          'Token': 'fcm-abc',
          'items': [
            {'PASSWORD': 'x', 'ok': 1},
          ],
        }),
        {
          'Token': kRedactedValue,
          'items': [
            {'PASSWORD': kRedactedValue, 'ok': 1},
          ],
        },
      );
    });

    test('masks inside a JSON string body', () {
      final redacted = redactForLog(jsonEncode({'password': 'x', 'a': 1}));
      expect(
          jsonDecode(redacted as String), {'password': kRedactedValue, 'a': 1});
    });

    test('leaves plain text, numbers and null alone', () {
      expect(redactForLog('hello'), 'hello');
      expect(redactForLog(42), 42);
      expect(redactForLog(null), isNull);
    });
  });

  group('redactUriForLog', () {
    test('masks a token query parameter', () {
      expect(
        redactUriForLog(
          Uri.parse('http://localhost:8080/viewer/devices?token=fcm-abc'),
        ),
        'http://localhost:8080/viewer/devices?token=***',
      );
    });

    test('keeps the other parameters', () {
      expect(
        redactUriForLog(
          Uri.parse('http://localhost:8080/x?days=7&token=t&campaignId=3'),
        ),
        'http://localhost:8080/x?days=7&token=***&campaignId=3',
      );
    });

    test('a url without a query is printed as is', () {
      expect(
        redactUriForLog(Uri.parse('http://localhost:8080/viewer/me')),
        'http://localhost:8080/viewer/me',
      );
    });
  });
}
