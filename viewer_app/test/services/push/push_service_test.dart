import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/push/push_client.dart';
import 'package:viewer_app/services/push/push_message.dart';
import 'package:viewer_app/services/push/push_service.dart';

import 'fakes.dart';

void main() {
  late FakePushClient client;
  late FakeRegistry registry;

  PushService build({PushPlatform platform = PushPlatform.android}) =>
      PushService(client: client, registry: registry, platform: platform);

  setUp(() {
    client = FakePushClient();
    registry = FakeRegistry();
  });

  test('permission denied -> no token registration', () async {
    client.permission = PushPermission.denied;
    await build().start();
    expect(registry.registered, isEmpty);
  });

  test('granted -> registers token with the right platform', () async {
    await build(platform: PushPlatform.ios).start();
    expect(registry.registered, [('tok-1', PushPlatform.ios)]);
    expect(PushPlatform.ios.wire, 'IOS');
    expect(PushPlatform.android.wire, 'ANDROID');
  });

  test('start is idempotent', () async {
    final s = build();
    await s.start();
    await s.start();
    expect(client.permissionCalls, 1);
    expect(registry.registered, hasLength(1));
  });

  test('denied permission is asked again on the next start', () async {
    client.permission = PushPermission.denied;
    final s = build();
    await s.start();
    await s.start();
    expect(client.permissionCalls, 2);
  });

  test('token refresh re-registers', () async {
    await build().start();
    client.refresh.add('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(registry.registered.map((e) => e.$1), ['tok-1', 'tok-2']);
  });

  test('registration failure is swallowed', () async {
    registry.failRegister = true;
    await build().start();
    expect(registry.registered, isEmpty);
  });

  test('stop unregisters the current token and stops refresh handling',
      () async {
    final s = build();
    await s.start();
    client.refresh.add('tok-2');
    await Future<void>.delayed(Duration.zero);
    await s.stop();
    expect(registry.unregistered, ['tok-2']);
    client.refresh.add('tok-3');
    await Future<void>.delayed(Duration.zero);
    expect(registry.registered.map((e) => e.$1), ['tok-1', 'tok-2']);
  });

  test('stop swallows unregister errors', () async {
    final s = build();
    await s.start();
    registry.failUnregister = true;
    await s.stop(); // must not throw
  });

  test('stop without start does nothing', () async {
    await build().stop();
    expect(registry.unregistered, isEmpty);
  });

  test('Firebase unavailable -> complete no-op', () async {
    final s = PushService(
      client: const UnavailablePushClient(),
      registry: registry,
      platform: PushPlatform.android,
    );
    await s.start();
    await s.stop();
    expect(registry.registered, isEmpty);
    expect(registry.unregistered, isEmpty);
  });
}
