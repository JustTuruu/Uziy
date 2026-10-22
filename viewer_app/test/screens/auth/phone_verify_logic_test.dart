import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/phone_verification.dart';
import 'package:viewer_app/screens/auth/phone_verify_logic.dart';

void main() {
  final expires = DateTime.utc(2026, 10, 13, 4, 5);
  final before = expires.subtract(const Duration(minutes: 1));
  final wellAfter =
      expires.add(kPhoneVerifyExpiryGrace + const Duration(seconds: 1));

  group('phaseAfterPoll', () {
    test('verified goes on to registering', () {
      expect(
        phaseAfterPoll(PhoneVerificationStatus.verified,
            expiresAt: expires, now: wellAfter),
        PhoneVerifyPhase.registering,
      );
    });

    test('expired from the backend is expired', () {
      expect(
        phaseAfterPoll(PhoneVerificationStatus.expired,
            expiresAt: expires, now: before),
        PhoneVerifyPhase.expired,
      );
    });

    test('pending keeps waiting before the deadline', () {
      expect(
        phaseAfterPoll(PhoneVerificationStatus.pending,
            expiresAt: expires, now: before),
        PhoneVerifyPhase.waiting,
      );
    });

    test('pending past the deadline gives up by itself', () {
      expect(
        phaseAfterPoll(PhoneVerificationStatus.pending,
            expiresAt: expires, now: wellAfter),
        PhoneVerifyPhase.expired,
      );
    });
  });

  group('isPastDeadline', () {
    test('allows the grace period after expiresAt', () {
      expect(isPastDeadline(expires, expires), isFalse);
      expect(isPastDeadline(expires, expires.add(kPhoneVerifyExpiryGrace)),
          isFalse);
      expect(isPastDeadline(expires, wellAfter), isTrue);
    });
  });

  test('only a 400 asks for a new code; other failures can be retried', () {
    expect(needsNewCode(400), isTrue);
    expect(needsNewCode(409), isFalse);
    expect(needsNewCode(503), isFalse);
  });

  test('polls no faster than verify.mn allows', () {
    expect(kPhoneVerifyPollInterval,
        greaterThanOrEqualTo(const Duration(seconds: 3)));
  });

  group('smsLaunchUri', () {
    PhoneVerification check({
      String smsUri = 'sms:144773?body=482916',
      String shortcode = '144773',
      String smsText = '482916',
    }) =>
        PhoneVerification(
          id: 'v1',
          phone: '88112233',
          shortcode: shortcode,
          smsText: smsText,
          smsUri: smsUri,
          displayInstruction: '',
          expiresAt: expires,
        );

    test('keeps the provider sms: link', () {
      expect(smsLaunchUri(check()).toString(), 'sms:144773?body=482916');
    });

    test('keeps an smsto: link, whatever its case', () {
      expect(
        smsLaunchUri(check(smsUri: 'SMSTO:144773:482916'))!.scheme,
        'smsto',
      );
    });

    for (final unsafe in [
      'https://evil.example/login',
      'tel:144773',
      'intent://pay#Intent;scheme=bank;end',
      'javascript:alert(1)',
      '',
    ]) {
      test('replaces "$unsafe" with a link built from the code', () {
        expect(
          smsLaunchUri(check(smsUri: unsafe)).toString(),
          'sms:144773?body=482916',
        );
      });
    }

    test('encodes the text of a built link', () {
      expect(
        smsLaunchUri(check(smsUri: '', smsText: 'UZ 4829&x=1')).toString(),
        'sms:144773?body=UZ%204829%26x%3D1',
      );
    });

    test('a built link without text has no body', () {
      expect(
        smsLaunchUri(check(smsUri: '', smsText: '')).toString(),
        'sms:144773',
      );
    });

    test('no usable link and no valid short code gives nothing', () {
      expect(smsLaunchUri(check(smsUri: 'tel:1', shortcode: '')), isNull);
      expect(
        smsLaunchUri(check(smsUri: 'tel:1', shortcode: '144773?x=1')),
        isNull,
      );
    });
  });
}
