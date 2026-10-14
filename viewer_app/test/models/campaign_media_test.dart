import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/campaign.dart';

void main() {
  test('cover paths resolve against the device API host', () {
    final campaign = Campaign.fromJson({
      'id': 1,
      'rewardPerUser': 700,
      'thumbnailUrl': '/public/campaigns/1/image?v=2',
    }, mediaBaseUrl: 'http://10.0.2.2:8080');
    expect(campaign.thumbnailUrl,
        'http://10.0.2.2:8080/public/campaigns/1/image?v=2');
  });
  test('existing absolute covers and absent images stay compatible', () {
    expect(
        Campaign.fromJson({
          'id': 1,
          'rewardPerUser': 700,
          'thumbnailUrl': 'https://cdn.example.com/a.png'
        }, mediaBaseUrl: 'http://localhost:8080')
            .thumbnailUrl,
        'https://cdn.example.com/a.png');
    expect(
        Campaign.fromJson({'id': 1, 'rewardPerUser': 700},
                mediaBaseUrl: 'http://localhost:8080')
            .thumbnailUrl,
        isNull);
  });
}
