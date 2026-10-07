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

  group('requestOtp', () {
    test('posts the phone and the backend purpose name', () async {
      final api = FakeApi.install((_) => const FakeReply(204));

      await AuthService.instance.requestOtp(
        phone: '88112233',
        purpose: OtpPurpose.passwordReset,
      );

      expect(api.calls.single.path, '/auth/otp/request');
      expect(api.calls.single.body, {
        'phoneNumber': '88112233',
        'purpose': 'PASSWORD_RESET',
      });
    });

    test('a taken phone (409) carries the backend message', () async {
      FakeApi.install((_) => const FakeReply(409, {'message': 'taken'}));

      final e = await _catch(
        () => AuthService.instance.requestOtp(
          phone: '88112233',
          purpose: OtpPurpose.register,
        ),
      );

      expect(e.statusCode, 409);
      expect(e.message, 'taken');
    });

    test('asking too soon (429) carries the backend message', () async {
      FakeApi.install(
        (_) => const FakeReply(
            429, {'message': 'Түр хүлээгээд дахин оролдоно уу'}),
      );

      final e = await _catch(
        () => AuthService.instance.requestOtp(
          phone: '88112233',
          purpose: OtpPurpose.register,
        ),
      );

      expect(e.statusCode, 429);
      expect(e.message, 'Түр хүлээгээд дахин оролдоно уу');
    });
  });

  group('resetPassword', () {
    test('posts phone, code and the new password', () async {
      final api = FakeApi.install((_) => const FakeReply(204));

      await AuthService.instance.resetPassword(
        phone: '88112233',
        code: '123456',
        newPassword: 'new-password',
      );

      expect(api.calls.single.path, '/auth/password/reset');
      expect(api.calls.single.body, {
        'phoneNumber': '88112233',
        'code': '123456',
        'newPassword': 'new-password',
      });
    });

    test('a wrong code (400) becomes an AuthException with the message',
        () async {
      FakeApi.install((_) => const FakeReply(400, {'message': 'Код буруу'}));

      final e = await _catch(
        () => AuthService.instance.resetPassword(
          phone: '88112233',
          code: '000000',
          newPassword: 'new-password',
        ),
      );

      expect(e.statusCode, 400);
      expect(e.message, 'Код буруу');
    });
  });

  group('register', () {
    test('sends the otp code with the profile', () async {
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
        gender: Gender.male,
        birthDate: DateTime(2000, 1, 2),
        city: 'Улаанбаатар',
        otpCode: '123456',
      );

      final body = api.calls.single.body as Map;
      expect(api.calls.single.path, '/auth/register/viewer');
      expect(body['otpCode'], '123456');
      expect(body['birthDate'], '2000-01-02');
      expect(body['gender'], 'MALE');
    });
  });
}
