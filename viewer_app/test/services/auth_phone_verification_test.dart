import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/phone_verification.dart';
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

const _started = {
  'verificationId': 'v1',
  'phoneNumber': '88112233',
  'shortcode': '144773',
  'smsText': '482916',
  'smsUri': 'sms:144773?body=482916',
  'displayInstruction': 'instruction',
  'status': 'PENDING',
  'expiresAt': '2026-10-13T04:05:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('startPhoneVerification', () {
    test('posts the phone and returns the opened check', () async {
      final api = FakeApi.install((_) => const FakeReply(201, _started));

      final v = await AuthService.instance.startPhoneVerification('88112233');

      expect(api.calls.single.method, 'POST');
      expect(api.calls.single.path, '/auth/phone-verifications');
      expect(api.calls.single.body,
          {'phoneNumber': '88112233', 'purpose': 'REGISTER'});
      expect(v.id, 'v1');
      expect(v.smsText, '482916');
    });

    test('a password reset sends its own purpose', () async {
      final api = FakeApi.install((_) => const FakeReply(201, _started));

      await AuthService.instance.startPhoneVerification(
        '88112233',
        purpose: PhoneCheckPurpose.passwordReset,
      );

      expect(api.calls.single.body,
          {'phoneNumber': '88112233', 'purpose': 'PASSWORD_RESET'});
    });

    test('resetting a phone with no account (404) carries the message',
        () async {
      FakeApi.install((_) =>
          const FakeReply(404, {'message': 'Энэ дугаараар бүртгэл олдсонгүй'}));

      final e = await _catch(() => AuthService.instance.startPhoneVerification(
            '88112233',
            purpose: PhoneCheckPurpose.passwordReset,
          ));

      expect(e.statusCode, 404);
      expect(e.message, 'Энэ дугаараар бүртгэл олдсонгүй');
    });

    test('a taken phone (409) carries the backend message', () async {
      FakeApi.install((_) => const FakeReply(409, {'message': 'taken'}));

      final e = await _catch(
          () => AuthService.instance.startPhoneVerification('88112233'));

      expect(e.statusCode, 409);
      expect(e.message, 'taken');
    });

    test('a provider outage (503) carries the backend message', () async {
      FakeApi.install(
          (_) => const FakeReply(503, {'message': 'эхлүүлж чадсангүй'}));

      final e = await _catch(
          () => AuthService.instance.startPhoneVerification('88112233'));

      expect(e.statusCode, 503);
      expect(e.message, 'эхлүүлж чадсангүй');
    });
  });

  group('phoneVerificationState', () {
    test('gets the check by id and parses the status', () async {
      final api = FakeApi.install(
        (_) => const FakeReply(200, {
          'verificationId': 'v1',
          'status': 'VERIFIED',
          'expiresAt': '2026-10-13T04:05:00Z',
        }),
      );

      final s = await AuthService.instance.phoneVerificationState('v1');

      expect(api.calls.single.method, 'GET');
      expect(api.calls.single.path, '/auth/phone-verifications/v1');
      expect(s.status, PhoneVerificationStatus.verified);
    });

    test('an unknown check (404) is an AuthException', () async {
      FakeApi.install((_) => const FakeReply(404, {'message': 'олдсонгүй'}));

      final e =
          await _catch(() => AuthService.instance.phoneVerificationState('x'));

      expect(e.statusCode, 404);
    });
  });
}
