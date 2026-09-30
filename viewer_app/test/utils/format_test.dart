import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/utils/format.dart';

void main() {
  group('formatGrouped', () {
    test('groups thousands with commas', () {
      expect(formatGrouped(0), '0');
      expect(formatGrouped(7), '7');
      expect(formatGrouped(999), '999');
      expect(formatGrouped(1000), '1,000');
      expect(formatGrouped(3400), '3,400');
      expect(formatGrouped(12345), '12,345');
      expect(formatGrouped(123456), '123,456');
      expect(formatGrouped(1234567), '1,234,567');
    });

    test('keeps the sign for negatives', () {
      expect(formatGrouped(-1), '-1');
      expect(formatGrouped(-999), '-999');
      expect(formatGrouped(-1000), '-1,000');
      expect(formatGrouped(-1500), '-1,500');
      expect(formatGrouped(-1234567), '-1,234,567');
    });

    test('64-bit extremes (abs() of the min int overflows)', () {
      const minInt = -9223372036854775807 - 1;
      const maxInt = 9223372036854775807;
      expect(formatGrouped(minInt), '-9,223,372,036,854,775,808');
      expect(formatGrouped(maxInt), '9,223,372,036,854,775,807');
    });
  });

  group('formatTugrik', () {
    test('formats with grouping and the tögrög sign', () {
      expect(formatTugrik(3400), '3,400 ₮');
      expect(formatTugrik(700), '700 ₮');
      expect(formatTugrik(1000000), '1,000,000 ₮');
    });

    test('zero never carries a sign', () {
      expect(formatTugrik(0), '0 ₮');
      expect(formatTugrik(0, withSign: true), '0 ₮');
      expect(formatTugrik(-0.0, withSign: true), '0 ₮');
      expect(formatTugrik(0.4, withSign: true), '0 ₮');
      expect(formatTugrik(-0.4), '0 ₮');
    });

    test('withSign adds + for positives only', () {
      expect(formatTugrik(700, withSign: true), '+700 ₮');
      expect(formatTugrik(3400, withSign: true), '+3,400 ₮');
      expect(formatTugrik(-2000, withSign: true), '-2,000 ₮');
    });

    test('negatives use a leading hyphen-minus', () {
      expect(formatTugrik(-2000), '-2,000 ₮');
      expect(formatTugrik(-5), '-5 ₮');
    });

    test('rounds doubles to the nearest whole tögrög (half away from 0)', () {
      expect(formatTugrik(699.4), '699 ₮');
      expect(formatTugrik(699.5), '700 ₮');
      expect(formatTugrik(999.6), '1,000 ₮');
      expect(formatTugrik(-2.5), '-3 ₮');
      expect(formatTugrik(3400.0), '3,400 ₮');
    });

    test('grouping boundaries', () {
      expect(formatTugrik(999), '999 ₮');
      expect(formatTugrik(1000), '1,000 ₮');
      expect(formatTugrik(1234567), '1,234,567 ₮');
      expect(formatTugrik(-999, withSign: true), '-999 ₮');
      expect(formatTugrik(1000, withSign: true), '+1,000 ₮');
    });

    test('doubles from JSON (e.g. 699.6) round, never show decimals', () {
      expect(formatTugrik(699.6), '700 ₮');
      expect(formatTugrik(699.6, withSign: true), '+700 ₮');
      expect(formatTugrik(0.5, withSign: true), '+1 ₮');
      expect(formatTugrik(-0.5), '-1 ₮');
      expect(formatTugrik(1234566.5), '1,234,567 ₮');
    });

    test('huge finite values never produce a double minus sign', () {
      expect(formatTugrik(-1e300), '-9,223,372,036,854,775,808 ₮');
      expect(
          formatTugrik(1e300, withSign: true), '+9,223,372,036,854,775,807 ₮');
    });

    test('non-finite input degrades to 0 ₮', () {
      expect(formatTugrik(double.nan), '0 ₮');
      expect(formatTugrik(double.infinity, withSign: true), '0 ₮');
      expect(formatTugrik(double.negativeInfinity), '0 ₮');
    });
  });

  group('formatDurationShort', () {
    test('under a minute -> "<s> сек"', () {
      expect(formatDurationShort(0), '0 сек');
      expect(formatDurationShort(1), '1 сек');
      expect(formatDurationShort(45), '45 сек');
      expect(formatDurationShort(59), '59 сек');
    });

    test('a minute or more -> m:ss', () {
      expect(formatDurationShort(60), '1:00');
      expect(formatDurationShort(90), '1:30');
      expect(formatDurationShort(120), '2:00');
      expect(formatDurationShort(605), '10:05');
    });

    test('an hour or more -> h:mm:ss', () {
      expect(formatDurationShort(3600), '1:00:00');
      expect(formatDurationShort(3725), '1:02:05');
    });

    test('negative input is treated as zero', () {
      expect(formatDurationShort(-10), '0 сек');
    });
  });

  group('formatClock', () {
    test('always shows minutes', () {
      expect(formatClock(0), '0:00');
      expect(formatClock(5), '0:05');
      expect(formatClock(45), '0:45');
      expect(formatClock(90), '1:30');
      expect(formatClock(3725), '1:02:05');
    });

    test('truncates fractions, clamps negatives / non-finite', () {
      expect(formatClock(44.9), '0:44');
      expect(formatClock(0.25), '0:00');
      expect(formatClock(-3), '0:00');
      expect(formatClock(double.nan), '0:00');
      expect(formatClock(double.infinity), '0:00');
    });
  });

  group('formatPhoneMn', () {
    test('formats an 8-digit number with the +976 prefix', () {
      expect(formatPhoneMn('88778899'), '+976 8877 8899');
      expect(formatPhoneMn('99112233'), '+976 9911 2233');
    });

    test('tolerates whitespace and separators', () {
      expect(formatPhoneMn(' 8877 8899 '), '+976 8877 8899');
      expect(formatPhoneMn('8877-8899'), '+976 8877 8899');
    });

    test('accepts numbers already carrying the country code', () {
      expect(formatPhoneMn('+97688778899'), '+976 8877 8899');
      expect(formatPhoneMn('97688778899'), '+976 8877 8899');
      expect(formatPhoneMn('+976 8877 8899'), '+976 8877 8899');
    });

    test('returns anything else unchanged', () {
      expect(formatPhoneMn(''), '');
      expect(formatPhoneMn('1234567'), '1234567');
      expect(formatPhoneMn('123456789'), '123456789');
      expect(formatPhoneMn('8877abcd'), '8877abcd');
      expect(formatPhoneMn('+1 555 0100'), '+1 555 0100');
    });
  });

  group('monogramOf', () {
    test('first letter, upper-cased', () {
      expect(monogramOf('MobiCom'), 'M');
      expect(monogramOf('golomt'), 'G');
      expect(monogramOf('  голомт'), 'Г');
      expect(monogramOf('өргөө'), 'Ө');
    });

    test('Mongolian-specific Cyrillic letters upper-case correctly', () {
      expect(monogramOf('үзье'), 'Ү');
      expect(monogramOf('ёс'), 'Ё');
      expect(monogramOf('Өргөө кино театр'), 'Ө');
    });

    test('skips leading quotes, brackets, symbols and emoji', () {
      expect(monogramOf('«Хаан банк»'), 'Х');
      expect(monogramOf('"Голомт" банк'), 'Г');
      expect(monogramOf('(Unitel)'), 'U');
      expect(monogramOf('\u{1F600} Uziy'), 'U');
      expect(monogramOf('7-Eleven'), '7');
    });

    test('keeps combining marks with their letter', () {
      // 'и' + combining breve = decomposed 'й'.
      expect(monogramOf('\u0438\u0306мж'), '\u0418\u0306');
    });

    test('falls back for null / blank', () {
      expect(monogramOf(null), 'U');
      expect(monogramOf('   '), 'U');
      expect(monogramOf('', fallback: '?'), '?');
      expect(monogramOf('«»', fallback: '?'), '?');
    });
  });
}
