import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/user.dart';

void main() {
  group('AppUser.fromJson', () {
    test('parses the backend Me DTO shape (camelCase)', () {
      final u = AppUser.fromJson({
        'id': 100,
        'phoneNumber': '88112233',
        'role': 'VIEWER',
        'gender': 'MALE',
        'age': 24,
        'city': 'Улаанбаатар',
        'balance': 3400.0,
        'isVerified': true,
        'companyName': null,
      });
      expect(u.id, 100);
      expect(u.phoneNumber, '88112233');
      expect(u.role, UserRole.viewer);
      expect(u.gender, Gender.male);
      expect(u.age, 24);
      expect(u.city, 'Улаанбаатар');
      expect(u.balance, 3400.0);
      expect(u.isVerified, isTrue);
    });

    test('handles missing optional fields (COMPANY account)', () {
      final u = AppUser.fromJson({
        'id': 2,
        'phoneNumber': '88112233',
        'role': 'COMPANY',
        'gender': null,
        'age': null,
        'city': null,
        'balance': 0.0,
        'isVerified': true,
        'companyName': 'MobiCom',
      });
      expect(u.role, UserRole.company);
      expect(u.gender, isNull);
      expect(u.age, isNull);
      expect(u.city, isNull);
      expect(u.companyName, 'MobiCom');
    });

    test('parses ADMIN role', () {
      final u = AppUser.fromJson({
        'id': 1,
        'phoneNumber': '99990000',
        'role': 'ADMIN',
        'balance': 0.0,
        'isVerified': true,
      });
      expect(u.role, UserRole.admin);
    });

    test('defaults balance to 0 when omitted', () {
      final u = AppUser.fromJson({
        'id': 1,
        'phoneNumber': '1',
        'role': 'VIEWER',
      });
      expect(u.balance, 0.0);
      expect(u.isVerified, isFalse);
    });
  });
}
