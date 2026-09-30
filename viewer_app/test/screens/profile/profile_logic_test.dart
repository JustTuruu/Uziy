import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/user.dart';
import 'package:viewer_app/screens/profile/profile_logic.dart';
import 'package:viewer_app/services/viewer_service.dart' show ApiException;

AppUser _user({
  String phone = '88778899',
  Gender? gender,
  int? age,
  String? city,
  String? district,
}) =>
    AppUser(
      id: 1,
      phoneNumber: phone,
      role: UserRole.viewer,
      gender: gender,
      age: age,
      city: city,
      district: district,
    );

void main() {
  group('genderLabel', () {
    test('maps both genders to Mongolian labels', () {
      expect(genderLabel(Gender.male), 'Эрэгтэй');
      expect(genderLabel(Gender.female), 'Эмэгтэй');
    });

    test('unknown gender falls back to a dash', () {
      expect(genderLabel(null), kEmptyValue);
      expect(kEmptyValue, '—');
    });
  });

  group('displayOrDash', () {
    test('null, empty and blank become a dash', () {
      expect(displayOrDash(null), '—');
      expect(displayOrDash(''), '—');
      expect(displayOrDash('   '), '—');
    });

    test('keeps real values, trimmed', () {
      expect(displayOrDash('Улаанбаатар'), 'Улаанбаатар');
      expect(displayOrDash('  Дархан '), 'Дархан');
    });
  });

  group('ageLabel', () {
    test('formats a known age as digits', () {
      expect(ageLabel(24), '24');
      expect(ageLabel(0), '0');
    });

    test('null or negative age becomes a dash', () {
      expect(ageLabel(null), '—');
      expect(ageLabel(-1), '—');
    });
  });

  group('phoneLabel', () {
    test('formats Mongolian numbers', () {
      expect(phoneLabel('88778899'), '+976 8877 8899');
      expect(phoneLabel('+97688778899'), '+976 8877 8899');
    });

    test('blank becomes a dash, unknown shapes pass through', () {
      expect(phoneLabel(null), '—');
      expect(phoneLabel('  '), '—');
      expect(phoneLabel('12345'), '12345');
    });
  });

  group('semantics labels', () {
    test('balance reads as a wallet shortcut only when it opens the wallet',
        () {
      expect(balanceSemantics(3400), 'Үлдэгдэл: 3,400 ₮');
      expect(
        balanceSemantics(3400, opensWallet: true),
        'Хэтэвч, үлдэгдэл 3,400 ₮',
      );
      expect(balanceSemantics(0), 'Үлдэгдэл: 0 ₮');
    });

    test('stat tiles announce the label before the value', () {
      expect(statSemantics('Нас', '24'), 'Нас: 24');
      expect(statSemantics('Хот', kEmptyValue), 'Хот: —');
    });
  });

  group('stackRetryAction', () {
    test('keeps the action inline on a roomy banner at normal text size', () {
      expect(stackRetryAction(width: 353, textScale: 1.0), isFalse);
      expect(stackRetryAction(width: 520, textScale: 1.15), isFalse);
    });

    test('stacks on a narrow banner', () {
      expect(stackRetryAction(width: 280, textScale: 1.0), isTrue);
      expect(stackRetryAction(width: 339.9, textScale: 1.0), isTrue);
      expect(stackRetryAction(width: 340, textScale: 1.0), isFalse);
    });

    test('stacks with large OS text even when wide', () {
      expect(stackRetryAction(width: 520, textScale: 1.3), isTrue);
    });
  });

  group('personalFields', () {
    test('full profile gives Хүйс, Нас, Хот, Дүүрэг in order', () {
      final fields = personalFields(
        _user(
          gender: Gender.female,
          age: 24,
          city: 'Улаанбаатар',
          district: 'Сүхбаатар',
        ),
      );
      expect(fields, const [
        ProfileField(ProfileFieldKind.gender, 'Хүйс', 'Эмэгтэй'),
        ProfileField(ProfileFieldKind.age, 'Нас', '24'),
        ProfileField(ProfileFieldKind.city, 'Хот', 'Улаанбаатар'),
        ProfileField(ProfileFieldKind.district, 'Дүүрэг', 'Сүхбаатар'),
      ]);
    });

    test('missing values fall back to a dash and district is omitted', () {
      final fields = personalFields(_user());
      expect(fields, const [
        ProfileField(ProfileFieldKind.gender, 'Хүйс', '—'),
        ProfileField(ProfileFieldKind.age, 'Нас', '—'),
        ProfileField(ProfileFieldKind.city, 'Хот', '—'),
      ]);
    });

    test('blank district is omitted, padded district is trimmed', () {
      expect(
        personalFields(_user(district: '  ')).map((f) => f.kind),
        isNot(contains(ProfileFieldKind.district)),
      );
      expect(
          personalFields(_user(district: ' Баянгол ')).last.value, 'Баянгол');
    });

    test('ProfileField has value equality', () {
      const a = ProfileField(ProfileFieldKind.age, 'Нас', '24');
      const b = ProfileField(ProfileFieldKind.age, 'Нас', '24');
      const c = ProfileField(ProfileFieldKind.age, 'Нас', '25');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('isSessionExpired / loadErrorMessage', () {
    test('only 401 and 403 ApiExceptions expire the session', () {
      expect(isSessionExpired(ApiException(401, 'x')), isTrue);
      expect(isSessionExpired(ApiException(403, 'x')), isTrue);
      expect(isSessionExpired(ApiException(404, 'x')), isFalse);
      expect(isSessionExpired(ApiException(500, 'x')), isFalse);
      expect(isSessionExpired(Exception('401')), isFalse);
      expect(isSessionExpired(TypeError()), isFalse);
    });

    test('ApiException keeps its own message, anything else is generic', () {
      expect(
        loadErrorMessage(ApiException(500, 'Профайл ачаалж чадсангүй')),
        'Профайл ачаалж чадсангүй',
      );
      expect(loadErrorMessage(TimeoutException('t')), kGenericLoadError);
      expect(loadErrorMessage(TypeError()), kGenericLoadError);
      expect(kGenericLoadError, 'Сервертэй холбогдож чадсангүй');
    });
  });

  group('loadProfile', () {
    late int clears;
    Future<void> clearOk() async => clears++;
    Future<void> clearThrows() async {
      clears++;
      throw Exception('secure storage unavailable');
    }

    setUp(() => clears = 0);

    test('success returns the user and never clears the token', () async {
      final u = _user(city: 'Дархан');
      final r = await loadProfile(fetch: () async => u, clearToken: clearOk);
      expect(r, isA<ProfileLoaded>());
      expect((r as ProfileLoaded).user, same(u));
      expect(clears, 0);
    });

    test('ApiException (not 401/403) shows its message', () async {
      final r = await loadProfile(
        fetch: () async => throw ApiException(500, 'Профайл ачаалж чадсангүй'),
        clearToken: clearOk,
      );
      expect(r, isA<ProfileLoadFailed>());
      expect((r as ProfileLoadFailed).message, 'Профайл ачаалж чадсангүй');
      expect(clears, 0);
    });

    test('any other error shows the generic message', () async {
      final r = await loadProfile(
        fetch: () async => throw TypeError(),
        clearToken: clearOk,
      );
      expect((r as ProfileLoadFailed).message, kGenericLoadError);
      expect(clears, 0);
    });

    for (final code in [401, 403]) {
      test('$code clears the token, then reports session expired', () async {
        final r = await loadProfile(
          fetch: () async => throw ApiException(code, 'x'),
          clearToken: clearOk,
        );
        expect(r, isA<ProfileSessionExpired>());
        expect(clears, 1);
      });
    }

    test('401 still reports session expired when clearing the token throws',
        () async {
      final r = await loadProfile(
        fetch: () async => throw ApiException(401, 'x'),
        clearToken: clearThrows,
      );
      expect(r, isA<ProfileSessionExpired>());
      expect(clears, 1);
    });
  });

  group('runLogout', () {
    test('cancel never clears the token', () async {
      var clears = 0;
      final r = await runLogout(
        confirm: () async => false,
        clearToken: () async => clears++,
      );
      expect(r, LogoutResult.cancelled);
      expect(clears, 0);
    });

    test('confirm clears the token before reporting done', () async {
      final events = <String>[];
      final gate = Completer<void>();
      final future = runLogout(
        confirm: () async {
          events.add('confirm');
          return true;
        },
        clearToken: () async {
          events.add('clear:start');
          await gate.future;
          events.add('clear:end');
        },
      );
      var finished = false;
      unawaited(future.then((_) => finished = true));
      await pumpEventQueue();
      expect(events, ['confirm', 'clear:start']);
      expect(finished, isFalse, reason: 'must wait for the token to clear');

      gate.complete();
      expect(await future, LogoutResult.done);
      expect(events, ['confirm', 'clear:start', 'clear:end']);
    });

    test('a failing clear reports failed instead of throwing', () async {
      final r = await runLogout(
        confirm: () async => true,
        clearToken: () async => throw Exception('storage'),
      );
      expect(r, LogoutResult.failed);
    });
  });

  group('SingleFlight', () {
    test('concurrent runs share one task', () async {
      final flight = SingleFlight<int>();
      final gate = Completer<int>();
      var starts = 0;
      Future<int> task() {
        starts++;
        return gate.future;
      }

      final a = flight.run(task);
      final b = flight.run(task);
      expect(starts, 1);
      expect(flight.isRunning, isTrue);

      gate.complete(7);
      expect(await a, 7);
      expect(await b, 7);
      expect(flight.isRunning, isFalse);
    });

    test('a run after completion starts a new task', () async {
      final flight = SingleFlight<int>();
      var starts = 0;
      expect(await flight.run(() async => ++starts), 1);
      expect(await flight.run(() async => ++starts), 2);
    });

    test('an error is shared, then the flight is free again', () async {
      final flight = SingleFlight<void>();
      final a = flight.run(() async => throw StateError('boom'));
      final b = flight.run(() async {});
      await expectLater(a, throwsStateError);
      await expectLater(b, throwsStateError);
      expect(flight.isRunning, isFalse);
      await flight.run(() async {}); // does not throw
    });
  });

  group('SessionCache', () {
    test('returns the value only for the same session key', () {
      final cache = SessionCache<AppUser>();
      final u = _user();
      expect(cache.read('Bearer a'), isNull);

      cache.write('Bearer a', u);
      expect(cache.read('Bearer a'), same(u));
      expect(cache.read('Bearer b'), isNull, reason: 'another account');
      expect(cache.read(null), isNull, reason: 'signed out');
    });

    test('clear and a null-key write forget the value', () {
      final cache = SessionCache<AppUser>()..write('Bearer a', _user());
      cache.clear();
      expect(cache.read('Bearer a'), isNull);

      cache
        ..write('Bearer a', _user())
        ..write(null, _user());
      expect(cache.read('Bearer a'), isNull);
    });
  });
}
