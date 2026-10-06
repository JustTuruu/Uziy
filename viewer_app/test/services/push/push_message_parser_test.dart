import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/push/push_message.dart';
import 'package:viewer_app/services/push/push_message_parser.dart';

void main() {
  const parser = PushMessageParser();

  test('valid video payload', () {
    final p = parser.parseData(
      {'type': 'CAMPAIGN', 'campaignId': '42', 'hasVideo': 'true'},
    );
    expect(p, const CampaignPush(campaignId: 42, hasVideo: true));
  });

  test('survey payload', () {
    final p = parser.parseData(
      {'type': 'CAMPAIGN', 'campaignId': '7', 'hasVideo': 'false'},
    );
    expect(p, const CampaignPush(campaignId: 7, hasVideo: false));
  });

  test('missing hasVideo defaults to video', () {
    expect(
      parser.parseData({'type': 'CAMPAIGN', 'campaignId': '7'})?.hasVideo,
      isTrue,
    );
  });

  test('hasVideo is case-insensitive', () {
    expect(
      parser
          .parseData({'type': 'CAMPAIGN', 'campaignId': '7', 'hasVideo': 'FALSE'})
          ?.hasVideo,
      isFalse,
    );
  });

  test('unknown type, missing type, bad or missing ids are ignored', () {
    expect(parser.parseData({'type': 'OTHER', 'campaignId': '1'}), isNull);
    expect(parser.parseData({'campaignId': '1'}), isNull);
    expect(parser.parseData({'type': 'CAMPAIGN'}), isNull);
    expect(parser.parseData({'type': 'CAMPAIGN', 'campaignId': 'abc'}), isNull);
    expect(parser.parseData({'type': 'CAMPAIGN', 'campaignId': '0'}), isNull);
    expect(parser.parseData({'type': 'CAMPAIGN', 'campaignId': '-3'}), isNull);
    expect(parser.parseData(const {}), isNull);
  });

  test('parse(PushMessage) reads the data map', () {
    const m = PushMessage(
      title: 'a',
      data: {'type': 'CAMPAIGN', 'campaignId': '5'},
    );
    expect(parser.parse(m)?.campaignId, 5);
  });
}
