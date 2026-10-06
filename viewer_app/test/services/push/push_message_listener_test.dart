import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/push/campaign_link_resolver.dart';
import 'package:viewer_app/services/push/foreground_notifier.dart';
import 'package:viewer_app/services/push/push_message.dart';
import 'package:viewer_app/services/push/push_message_listener.dart';
import 'package:viewer_app/services/push/push_navigator.dart';

import 'fakes.dart';

const _video = {'type': 'CAMPAIGN', 'campaignId': '1', 'hasVideo': 'true'};
const _survey = {'type': 'CAMPAIGN', 'campaignId': '2', 'hasVideo': 'false'};

void main() {
  late FakePushClient client;
  late FakeNotifier notifier;
  late FakeTarget target;
  late PushNavigator navigator;

  PushMessageListener build({bool showForeground = true}) =>
      PushMessageListener(
        client: client,
        notifier: notifier,
        navigator: navigator,
        showForeground: showForeground,
      );

  setUp(() {
    client = FakePushClient();
    notifier = FakeNotifier();
    target = FakeTarget();
    navigator = PushNavigator(
      resolver: CampaignLinkResolver(
        () async => [campaign(1), campaign(2, hasVideo: false)],
      ),
      target: target,
      videoRoute: '/video',
      surveyRoute: '/survey',
    );
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('foreground message is shown locally on Android only', () async {
    await build().attach();
    client.messages.add(const PushMessage(title: 'a', data: _video));
    await pump();
    expect(notifier.shown, hasLength(1));

    final ios = build(showForeground: false);
    notifier.shown.clear();
    await ios.attach();
    client.messages.add(const PushMessage(title: 'b', data: _video));
    await pump();
    expect(notifier.shown, hasLength(1)); // only the first listener
  });

  test('background tap opens video', () async {
    await navigator.markReady();
    await build().attach();
    client.opened.add(const PushMessage(data: _video));
    await pump();
    await pump();
    expect(target.pushed.single.$1, '/video/1');
  });

  test('terminated tap (initial message) waits for Home then opens survey',
      () async {
    client.initial = const PushMessage(data: _survey);
    await build().attach();
    await pump();
    expect(target.pushed, isEmpty);
    await navigator.markReady();
    expect(target.pushed.single.$1, '/survey/2');
  });

  test('foreground local-notification tap navigates', () async {
    await navigator.markReady();
    await build().attach();
    notifier.tapController.add(_survey);
    await pump();
    await pump();
    expect(target.pushed.single.$1, '/survey/2');
  });

  test('invalid payload is ignored', () async {
    await navigator.markReady();
    await build().attach();
    client.opened.add(const PushMessage(data: {'type': 'X'}));
    await pump();
    expect(target.pushed, isEmpty);
    expect(target.homes, 0);
  });

  test('unavailable client attaches nothing', () async {
    client.available = false;
    await build().attach();
    client.opened.add(const PushMessage(data: _video));
    await pump();
    expect(target.pushed, isEmpty);
  });

  test('decodePayload', () {
    expect(LocalForegroundNotifier.decodePayload('{"a":1}'), {'a': '1'});
    expect(LocalForegroundNotifier.decodePayload('nope'), isNull);
    expect(LocalForegroundNotifier.decodePayload(null), isNull);
    expect(LocalForegroundNotifier.decodePayload('[1]'), isNull);
  });
}
