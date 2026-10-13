import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/phone_verification.dart';

void main() {
  group('PhoneVerification.fromJson', () {
    test('parses exactly what POST /auth/phone-verifications sends', () {
      final v = PhoneVerification.fromJson({
        'verificationId': '11111111-2222-3333-4444-555555555555',
        'phoneNumber': '88112233',
        'shortcode': '144773',
        'smsText': '482916',
        'smsUri': 'sms:144773?body=482916',
        'displayInstruction': 'Та өөрийн 88112233 дугаараас 144773 ...',
        'status': 'PENDING',
        'expiresAt': '2026-10-13T04:05:00Z',
      });

      expect(v.id, '11111111-2222-3333-4444-555555555555');
      expect(v.phone, '88112233');
      expect(v.shortcode, '144773');
      expect(v.smsText, '482916');
      expect(v.smsUri, 'sms:144773?body=482916');
      expect(v.displayInstruction, 'Та өөрийн 88112233 дугаараас 144773 ...');
      expect(v.expiresAt, DateTime.utc(2026, 10, 13, 4, 5));
    });

    test('missing optional strings fall back to empty', () {
      final v = PhoneVerification.fromJson({
        'verificationId': 'v1',
        'expiresAt': '2026-10-13T04:05:00Z',
      });

      expect(v.smsUri, '');
      expect(v.displayInstruction, '');
    });
  });

  group('PhoneVerificationState.fromJson', () {
    test('parses status and expiry', () {
      final s = PhoneVerificationState.fromJson({
        'verificationId': 'v1',
        'status': 'VERIFIED',
        'expiresAt': '2026-10-13T04:05:00.000Z',
      });

      expect(s.status, PhoneVerificationStatus.verified);
      expect(s.expiresAt, DateTime.utc(2026, 10, 13, 4, 5));
    });
  });

  group('PhoneVerificationStatus.fromWire', () {
    test('maps every backend name', () {
      expect(PhoneVerificationStatus.fromWire('PENDING'),
          PhoneVerificationStatus.pending);
      expect(PhoneVerificationStatus.fromWire('VERIFIED'),
          PhoneVerificationStatus.verified);
      expect(PhoneVerificationStatus.fromWire('EXPIRED'),
          PhoneVerificationStatus.expired);
    });

    test('an unknown or missing value keeps the app polling', () {
      expect(PhoneVerificationStatus.fromWire('NEW_THING'),
          PhoneVerificationStatus.pending);
      expect(PhoneVerificationStatus.fromWire(null),
          PhoneVerificationStatus.pending);
    });
  });
}
