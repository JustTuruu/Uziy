import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/services/auth_service.dart';

void main() {
  tearDown(() => ApiService.instance.setAuthToken(null));

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
}
