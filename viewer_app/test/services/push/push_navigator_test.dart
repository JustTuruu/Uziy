import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/push/campaign_link_resolver.dart';
import 'package:viewer_app/services/push/push_navigator.dart';
import 'package:viewer_app/services/push/push_message_parser.dart';

import 'fakes.dart';

void main() {
  late FakeTarget target;

  PushNavigator build(Future<List<dynamic>> Function() feed) {
    return PushNavigator(
      resolver: CampaignLinkResolver(() async => (await feed()).cast()),
      target: target,
      videoRoute: '/video',
      surveyRoute: '/survey',
    );
  }

  setUp(() => target = FakeTarget());

  test('hasVideo=true opens the video route with the real campaign',
      () async {
    final c = campaign(5);
    final n = build(() async => [c]);
    await n.markReady();
    await n.open(const CampaignPush(campaignId: 5, hasVideo: true));
    expect(target.pushed, [('/video/5', c)]);
  });

  test('hasVideo=false opens the survey route', () async {
    final n = build(() async => [campaign(6, hasVideo: false)]);
    await n.markReady();
    await n.open(const CampaignPush(campaignId: 6, hasVideo: false));
    expect(target.pushed.single.$1, '/survey/6');
  });

  test('not found -> Home + Mongolian message, no crash', () async {
    final n = build(() async => []);
    await n.markReady();
    await n.open(const CampaignPush(campaignId: 1, hasVideo: true));
    expect(target.pushed, isEmpty);
    expect(target.homes, 1);
    expect(target.messages, [PushNavigator.notFoundMessage]);
  });

  test('lookup failure -> message only', () async {
    final n = build(() async => throw Exception('net'));
    await n.markReady();
    await n.open(const CampaignPush(campaignId: 1, hasVideo: true));
    expect(target.messages, [PushNavigator.loadFailedMessage]);
    expect(target.homes, 0);
  });

  test('taps before Home are held and replayed by markReady', () async {
    final n = build(() async => [campaign(3)]);
    await n.open(const CampaignPush(campaignId: 3, hasVideo: true));
    expect(target.pushed, isEmpty);
    await n.markReady();
    expect(target.pushed.single.$1, '/video/3');
    await n.markReady(); // not replayed twice
    expect(target.pushed, hasLength(1));
  });

  test('markNotReady drops a held tap', () async {
    final n = build(() async => [campaign(3)]);
    await n.open(const CampaignPush(campaignId: 3, hasVideo: true));
    n.markNotReady();
    await n.markReady();
    expect(target.pushed, isEmpty);
  });
}
