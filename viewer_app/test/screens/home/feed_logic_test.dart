import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/campaign.dart';
import 'package:viewer_app/screens/home/feed_logic.dart';

Campaign _c({
  int id = 1,
  double reward = 500,
  bool hasVideo = true,
  int duration = 45,
  String title = 'Гарчиг',
  String company = 'MobiCom',
}) =>
    Campaign(
      id: id,
      companyName: company,
      videoUrl: '',
      title: title,
      durationSeconds: duration,
      rewardPerUser: reward,
      hasVideo: hasVideo,
    );

void main() {
  group('summarizeFeed', () {
    test('mock feed: totals and counts', () {
      final s = summarizeFeed(Campaign.mockFeed());
      expect(s.totalReward, 1450); // 700 + 500 + 250
      expect(s.videoCount, 2);
      expect(s.surveyCount, 1);
      expect(s.itemCount, 3);
      expect(s.isEmpty, isFalse);
      expect(s.hasBothKinds, isTrue);
    });

    test('empty list is the empty summary', () {
      final s = summarizeFeed(const []);
      expect(s, FeedSummary.empty);
      expect(s.totalReward, 0);
      expect(s.itemCount, 0);
      expect(s.isEmpty, isTrue);
      expect(s.hasBothKinds, isFalse);
    });

    test('rounds half away from zero', () {
      expect(summarizeFeed([_c(reward: 699.5)]).totalReward, 700);
      expect(summarizeFeed([_c(reward: 699.49)]).totalReward, 699);
    });

    test('sums doubles first and rounds once', () {
      // Rounding each item would give 0 + 0 = 0.
      expect(
        summarizeFeed([_c(reward: 0.4), _c(id: 2, reward: 0.4)]).totalReward,
        1,
      );
      // Rounding each item would give 100 + 200 = 300.
      expect(
        summarizeFeed([_c(reward: 100.25), _c(id: 2, reward: 200.25)])
            .totalReward,
        301,
      );
    });

    test('absorbs floating-point noise', () {
      // 0.1 + 0.2 == 0.30000000000000004 and 333.3 * 3 + 0.1 drifts too.
      expect(
        summarizeFeed([_c(reward: 0.1), _c(id: 2, reward: 0.2)]).totalReward,
        0,
      );
      expect(
        summarizeFeed([
          _c(reward: 333.3),
          _c(id: 2, reward: 333.3),
          _c(id: 3, reward: 333.4),
        ]).totalReward,
        1000,
      );
    });

    test('ignores non-finite and negative rewards but still counts items', () {
      final s = summarizeFeed([
        _c(reward: double.nan),
        _c(id: 2, reward: 500),
        _c(id: 3, reward: -100, hasVideo: false),
        _c(id: 4, reward: double.infinity, hasVideo: false),
      ]);
      expect(s.totalReward, 500);
      expect(s.videoCount, 2);
      expect(s.surveyCount, 2);
    });

    test('only one kind', () {
      final videos = summarizeFeed([_c(), _c(id: 2)]);
      expect(videos.videoCount, 2);
      expect(videos.surveyCount, 0);
      expect(videos.hasBothKinds, isFalse);

      final surveys = summarizeFeed([_c(hasVideo: false)]);
      expect(surveys.videoCount, 0);
      expect(surveys.surveyCount, 1);
      expect(surveys.hasBothKinds, isFalse);
    });

    test('value equality', () {
      const a = FeedSummary(totalReward: 1, videoCount: 2, surveyCount: 3);
      const b = FeedSummary(totalReward: 1, videoCount: 2, surveyCount: 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(const FeedSummary(totalReward: 2, videoCount: 2, surveyCount: 3)),
      );
    });
  });

  group('summaryCaption', () {
    test('both kinds', () {
      expect(
        summaryCaption(
          const FeedSummary(totalReward: 0, videoCount: 2, surveyCount: 1),
        ),
        '2 видео · 1 судалгаа',
      );
    });

    test('only the non-zero kind', () {
      expect(
        summaryCaption(
          const FeedSummary(totalReward: 0, videoCount: 3, surveyCount: 0),
        ),
        '3 видео',
      );
      expect(
        summaryCaption(
          const FeedSummary(totalReward: 0, videoCount: 0, surveyCount: 1),
        ),
        '1 судалгаа',
      );
    });

    test('empty feed gives an empty caption', () {
      expect(summaryCaption(FeedSummary.empty), '');
    });
  });

  group('filterFeed', () {
    final feed = [
      _c(id: 1),
      _c(id: 2, hasVideo: false),
      _c(id: 3),
      _c(id: 4, hasVideo: false),
    ];
    List<int> ids(List<Campaign> l) => l.map((c) => c.id).toList();

    test('all keeps everything in order', () {
      expect(ids(filterFeed(feed, FeedFilter.all)), [1, 2, 3, 4]);
    });

    test('video keeps only video campaigns, in order', () {
      expect(ids(filterFeed(feed, FeedFilter.video)), [1, 3]);
    });

    test('survey keeps only survey-only campaigns, in order', () {
      expect(ids(filterFeed(feed, FeedFilter.survey)), [2, 4]);
    });

    test('empty input gives empty output for every mode', () {
      for (final f in FeedFilter.values) {
        expect(filterFeed(const [], f), isEmpty, reason: f.name);
      }
    });

    test('never aliases or mutates the input', () {
      final input = List<Campaign>.of(feed);
      final all = filterFeed(input, FeedFilter.all);
      expect(identical(all, input), isFalse);
      all.clear();
      expect(input.length, 4);
    });
  });

  group('filter visibility', () {
    const mixed = FeedSummary(totalReward: 0, videoCount: 1, surveyCount: 1);
    const videosOnly =
        FeedSummary(totalReward: 0, videoCount: 2, surveyCount: 0);

    test('filter bar shows only for a mixed feed', () {
      expect(shouldShowFilter(mixed), isTrue);
      expect(shouldShowFilter(videosOnly), isFalse);
      expect(shouldShowFilter(FeedSummary.empty), isFalse);
    });

    test('effectiveFilter falls back to all when the bar is hidden', () {
      expect(effectiveFilter(FeedFilter.survey, mixed), FeedFilter.survey);
      expect(effectiveFilter(FeedFilter.survey, videosOnly), FeedFilter.all);
      expect(
          effectiveFilter(FeedFilter.video, FeedSummary.empty), FeedFilter.all);
    });

    test('labels', () {
      expect(feedFilterLabel(FeedFilter.all), 'Бүгд');
      expect(feedFilterLabel(FeedFilter.video), 'Видео');
      expect(feedFilterLabel(FeedFilter.survey), 'Судалгаа');
    });
  });

  group('greeting', () {
    DayPart at(int h, [int m = 0]) => dayPartOf(DateTime(2026, 9, 28, h, m));

    test('day-part boundaries', () {
      expect(at(0), DayPart.night);
      expect(at(4, 59), DayPart.night);
      expect(at(5), DayPart.morning);
      expect(at(11, 59), DayPart.morning);
      expect(at(12), DayPart.afternoon);
      expect(at(17, 59), DayPart.afternoon);
      expect(at(18), DayPart.evening);
      expect(at(22, 59), DayPart.evening);
      expect(at(23), DayPart.night);
    });

    test('Mongolian greetings', () {
      expect(greetingFor(DayPart.morning), 'Өглөөний мэнд');
      expect(greetingFor(DayPart.afternoon), 'Өдрийн мэнд');
      expect(greetingFor(DayPart.evening), 'Оройн мэнд');
      expect(greetingFor(DayPart.night), 'Сайн байна уу');
    });
  });

  group('card copy', () {
    test('CTA label', () {
      expect(campaignCtaLabel(_c()), 'Үзэх');
      expect(campaignCtaLabel(_c(hasVideo: false)), 'Бөглөх');
    });

    test('kind label uses the short duration or Судалгаа', () {
      expect(campaignKindLabel(_c(duration: 45)), '45 сек');
      expect(campaignKindLabel(_c(duration: 90)), '1:30');
      expect(campaignKindLabel(_c(hasVideo: false, duration: 0)), 'Судалгаа');
    });

    test('semantic label for a video', () {
      expect(
        campaignSemanticLabel(
          _c(title: 'Шинэ 5G багц', company: 'MobiCom', reward: 700),
        ),
        'Шинэ 5G багц. MobiCom. Видео, 45 сек. Урамшуулал +700 ₮',
      );
    });

    test('semantic label for a survey, blank company skipped', () {
      expect(
        campaignSemanticLabel(
          _c(title: 'Судалгаа', company: '  ', reward: 250, hasVideo: false),
        ),
        'Судалгаа. Судалгаа. Урамшуулал +250 ₮',
      );
    });
  });

  group('splitCampaignTitle', () {
    test('splits at " - " into headline and tagline', () {
      expect(
        splitCampaignTitle('Шинэ 5G багц - Танд хамгийн тохирсон'),
        const TitleParts('Шинэ 5G багц', 'Танд хамгийн тохирсон'),
      );
    });

    test('splits at en and em dashes too', () {
      expect(splitCampaignTitle('A – B'), const TitleParts('A', 'B'));
      expect(splitCampaignTitle('A — B'), const TitleParts('A', 'B'));
    });

    test('a colon is not a separator', () {
      expect(
        splitCampaignTitle('Судалгаа: Дуртай интернэт үйлчилгээ'),
        const TitleParts('Судалгаа: Дуртай интернэт үйлчилгээ'),
      );
    });

    test('splits at the first separator only', () {
      expect(
        splitCampaignTitle('A - B - C'),
        const TitleParts('A', 'B - C'),
      );
    });

    test('a hyphen inside a word is not a separator', () {
      expect(splitCampaignTitle('Wi-Fi багц'), const TitleParts('Wi-Fi багц'));
    });

    test('no separator keeps the whole title as the headline', () {
      expect(splitCampaignTitle('  Зуны хямдрал '),
          const TitleParts('Зуны хямдрал'));
    });

    test('an empty side is not split', () {
      expect(splitCampaignTitle('Багц - '), const TitleParts('Багц -'));
      expect(splitCampaignTitle('- Багц'), const TitleParts('- Багц'));
    });
  });
}
