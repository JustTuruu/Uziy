import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/auth/otp_logic.dart';

void main() {
  group('formatCountdown', () {
    test('formats minutes and zero-padded seconds', () {
      expect(formatCountdown(60), '1:00');
      expect(formatCountdown(45), '0:45');
      expect(formatCountdown(9), '0:09');
      expect(formatCountdown(0), '0:00');
    });

    test('negative counts as zero', () {
      expect(formatCountdown(-5), '0:00');
    });
  });

  group('resendLabel', () {
    test('shows the time left while locked', () {
      expect(resendLabel(45), 'Дахин илгээх (0:45)');
    });

    test('is the plain label once unlocked', () {
      expect(resendLabel(0), kOtpResendLabel);
      expect(resendLabel(-1), kOtpResendLabel);
    });
  });

  test('otpSubtitle names the phone', () {
    expect(
      otpSubtitle('+976 8811 2233'),
      'Бид +976 8811 2233 дугаарт 6 оронтой код илгээлээ',
    );
  });

  test('isCompleteCode needs every digit', () {
    expect(isCompleteCode('123456'), isTrue);
    expect(isCompleteCode('12345'), isFalse);
    expect(isCompleteCode(''), isFalse);
    expect(isCompleteCode('1234', length: 4), isTrue);
  });
}
