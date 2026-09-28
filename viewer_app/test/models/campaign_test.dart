import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/campaign.dart';

void main() {
  group('Campaign.fromJson', () {
    test('parses a video campaign with all fields', () {
      final c = Campaign.fromJson({
        'id': 1,
        'title': 'Шинэ 5G багц',
        'videoUrl': 'https://cdn.uziy.mn/hls/1/master.m3u8',
        'thumbnailUrl': 'https://cdn.uziy.mn/thumb/1.jpg',
        'durationSeconds': 45,
        'hasVideo': true,
        'rewardPerUser': 700,
        'companyName': 'MobiCom',
      });
      expect(c.id, 1);
      expect(c.title, 'Шинэ 5G багц');
      expect(c.videoUrl, contains('master.m3u8'));
      expect(c.thumbnailUrl, contains('thumb/1.jpg'));
      expect(c.durationSeconds, 45);
      expect(c.hasVideo, true);
      expect(c.rewardPerUser, 700);
      expect(c.companyName, 'MobiCom');
    });

    test('parses a survey-only campaign (hasVideo=false, duration=0)', () {
      final c = Campaign.fromJson({
        'id': 7,
        'title': 'Танай brand-ийг таньж байна уу?',
        'videoUrl': '',
        'thumbnailUrl': null,
        'durationSeconds': 0,
        'hasVideo': false,
        'rewardPerUser': 250,
        'companyName': 'Golomt',
      });
      expect(c.hasVideo, false);
      expect(c.durationSeconds, 0);
      expect(c.videoUrl, '');
      expect(c.thumbnailUrl, isNull);
    });

    test('defaults hasVideo to true when omitted (backward compat)', () {
      final c = Campaign.fromJson({
        'id': 1,
        'title': 'x',
        'videoUrl': 'x',
        'durationSeconds': 30,
        'rewardPerUser': 500,
      });
      expect(c.hasVideo, true);
    });

    test('coerces numeric id + rewardPerUser from doubles too', () {
      final c = Campaign.fromJson({
        'id': 42.0,
        'title': 'x',
        'videoUrl': '',
        'durationSeconds': 30.0,
        'rewardPerUser': 500.5,
      });
      expect(c.id, 42);
      expect(c.rewardPerUser, 500.5);
      expect(c.durationSeconds, 30);
    });
  });

  group('Campaign.mockFeed', () {
    test('includes at least one survey-only entry for local dev', () {
      final feed = Campaign.mockFeed();
      expect(feed.any((c) => !c.hasVideo), isTrue,
          reason: 'the survey-only path needs a mock example to render');
    });
  });
}
