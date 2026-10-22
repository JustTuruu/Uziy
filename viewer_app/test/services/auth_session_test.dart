import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/services/auth_service.dart';
import 'package:viewer_app/widgets/animated_money.dart';

void main() {
  tearDown(() {
    ApiService.instance.setAuthToken(null);
    AuthService.instance.onBeforeLogout = null;
    MoneyMemory.clear();
  });

  test('a guest is not signed in', () {
    ApiService.instance.setAuthToken(null);
    expect(AuthService.instance.isSignedIn, isFalse);
  });

  test('a loaded token means signed in, clearing it means guest again', () {
    ApiService.instance.setAuthToken('jwt');
    expect(AuthService.instance.isSignedIn, isTrue);

    ApiService.instance.setAuthToken(null);
    expect(AuthService.instance.isSignedIn, isFalse);
  });

  group('logout', () {
    test('forgets the token and the last shown balance', () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'jwt'});
      ApiService.instance.setAuthToken('jwt');
      MoneyMemory.remember(MoneyMemory.balance, 3400);

      await AuthService.instance.logout();

      expect(AuthService.instance.isSignedIn, isFalse);
      expect(await AuthService.instance.readToken(), isNull);
      expect(MoneyMemory.lastShown(MoneyMemory.balance), isNull);
    });

    test('a failing push unregister does not keep the session', () async {
      FlutterSecureStorage.setMockInitialValues({});
      ApiService.instance.setAuthToken('jwt');
      MoneyMemory.remember(MoneyMemory.balance, 3400);
      AuthService.instance.onBeforeLogout = () async => throw StateError('x');

      await AuthService.instance.logout();

      expect(AuthService.instance.isSignedIn, isFalse);
      expect(MoneyMemory.lastShown(MoneyMemory.balance), isNull);
    });
  });
}
