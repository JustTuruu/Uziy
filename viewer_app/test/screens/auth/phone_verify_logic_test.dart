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
}
