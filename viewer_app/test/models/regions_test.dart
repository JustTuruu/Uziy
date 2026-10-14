import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/regions.dart';

void main() {
  test('the capital first, then all 21 aimags, no duplicates', () {
    expect(kRegisterCities.first, kCapital);
    expect(kAimags, hasLength(21));
    expect(kRegisterCities.toSet(), hasLength(22));
    expect(kCapitalDistricts, hasLength(9));
  });

  test('names match the backend spelling exactly', () {
    // MongolianRegions.java: any difference would silently break targeting.
    expect(
        kAimags, containsAll(['Дархан-Уул', 'Орхон', 'Баян-Өлгий', 'Хөвсгөл']));
    expect(kAimags, isNot(contains('Дархан')));
    expect(kCapitalDistricts, containsAll(['Хан-Уул', 'Сонгинохайрхан']));
  });

  group('districtFor', () {
    test('the capital sends only a listed district', () {
      expect(districtFor(kCapital, 'Баянзүрх'), 'Баянзүрх');
      expect(districtFor(kCapital, ''), isNull);
      expect(districtFor(kCapital, 'Жаргалант'), isNull);
    });

    test('an aimag sends the typed sum, or nothing', () {
      expect(districtFor('Ховд', '  Жаргалант '), 'Жаргалант');
      expect(districtFor('Ховд', '   '), isNull);
    });
  });
}
