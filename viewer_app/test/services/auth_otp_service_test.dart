import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/user.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/services/auth_service.dart';

import '../support/fake_api.dart';

Future<AuthException> _catch(Future<Object?> Function() call) async {
  try {
    await call();
  } on AuthException catch (e) {
    return e;
  }
  fail('expected AuthException');
}

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // register() saves the JWT; give it a storage that accepts the write.
  setUp(() => binding.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorage, (call) async => null));
  tearDown(() {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
    ApiService.instance.setAuthToken(null);
  });

  group('resetPassword', () {
    test('posts the phone, the confirmed check and the new password', () async {
      final api = FakeApi.install((_) => const FakeReply(204));

      await AuthService.instance.resetPassword(
        phone: '88112233',
        verificationId: 'check-9',
        newPassword: 'new-password',
      );

      expect(api.calls.single.path, '/auth/password/reset');
      expect(api.calls.single.body, {
        'phoneNumber': '88112233',
        'verificationId': 'check-9',
        'newPassword': 'new-password',
      });
    });

    test('an unusable check (400) becomes an AuthException with the message',
        () async {
      FakeApi.install((_) => const FakeReply(
          400, {'message': 'Утасны дугаар баталгаажаагүй байна'}));

      final e = await _catch(
        () => AuthService.instance.resetPassword(
          phone: '88112233',
          verificationId: 'check-9',
          newPassword: 'new-password',
        ),
      );

      expect(e.statusCode, 400);
      expect(e.message, 'Утасны дугаар баталгаажаагүй байна');
    });
  });

  group('register', () {
    test('sends the confirmed phone check with the profile', () async {
      final api = FakeApi.install(
        (_) => const FakeReply(201, {
          'token': 'jwt',
          'user': {
            'id': 1,
            'phoneNumber': '88112233',
            'role': 'VIEWER',
            'balance': 0,
            'isVerified': false,
          },
        }),
      );

      await AuthService.instance.register(
        phone: '88112233',
        password: 'password1',
        lastName: 'Оюун-Эрдэнэ',
        firstName: 'Төрболд',
        gender: Gender.male,
        birthDate: DateTime(2000, 1, 2),
        city: 'Улаанбаатар',
        verificationId: 'check-1',
      );

      final body = api.calls.single.body as Map;
      expect(api.calls.single.path, '/auth/register/viewer');
      expect(body['verificationId'], 'check-1');
      expect(body.containsKey('otpCode'), isFalse);
      expect(body['birthDate'], '2000-01-02');
      expect(body['gender'], 'MALE');
      expect(body['lastName'], 'Оюун-Эрдэнэ');
      expect(body['firstName'], 'Төрболд');
    });
  });
}
