import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/push/campaign_link_resolver.dart';
import 'package:viewer_app/services/push/push_message_parser.dart';

import 'fakes.dart';

void main() {
  final resolver = CampaignLinkResolver(
    () async => [campaign(1), campaign(2, hasVideo: false)],
  );

  test('returns the campaign when it is in the feed', () async {
    final c = await resolver.resolve(
      const CampaignPush(campaignId: 2, hasVideo: false),
    );
    expect(c?.id, 2);
  });

  test('returns null when watched / expired', () async {
    expect(
      await resolver.resolve(const CampaignPush(campaignId: 9, hasVideo: true)),
      isNull,
    );
  });

  test('propagates feed errors', () {
    final failing = CampaignLinkResolver(() async => throw Exception('net'));
    expect(
      failing.resolve(const CampaignPush(campaignId: 1, hasVideo: true)),
      throwsException,
    );
  });
}
