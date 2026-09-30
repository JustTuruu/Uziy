/// Pure, UI-free helpers for the home feed.
///
/// Nothing here imports Flutter widgets or the router, so it can be unit
/// tested in isolation (see test/screens/home/feed_logic_test.dart).
library;

import '../../models/campaign.dart';
import '../../utils/format.dart';

/// Feed filter tabs: everything, video campaigns, survey-only campaigns.
enum FeedFilter { all, video, survey }

/// Mongolian label for a filter tab.
String feedFilterLabel(FeedFilter filter) => switch (filter) {
      FeedFilter.all => 'Бүгд',
      FeedFilter.video => 'Видео',
      FeedFilter.survey => 'Судалгаа',
    };

/// Campaigns matching [filter]. Always returns a new list (the input is
/// never aliased or mutated) and keeps the server's order.
List<Campaign> filterFeed(List<Campaign> feed, FeedFilter filter) {
  return switch (filter) {
    FeedFilter.all => List<Campaign>.of(feed),
    FeedFilter.video => feed.where((c) => c.hasVideo).toList(),
    FeedFilter.survey => feed.where((c) => !c.hasVideo).toList(),
  };
}

/// What the current feed is worth, for the "earning potential" hero card.
class FeedSummary {
  const FeedSummary({
    required this.totalReward,
    required this.videoCount,
    required this.surveyCount,
  });

  static const FeedSummary empty =
      FeedSummary(totalReward: 0, videoCount: 0, surveyCount: 0);

  /// Sum of every campaign's reward, rounded once (half away from zero) to
  /// whole tögrög.
  final int totalReward;

  /// Campaigns with a video (the survey follows the video).
  final int videoCount;

  /// Survey-only campaigns.
  final int surveyCount;

  int get itemCount => videoCount + surveyCount;
  bool get isEmpty => itemCount == 0;

  /// Both kinds are present, so filtering by kind is meaningful.
  bool get hasBothKinds => videoCount > 0 && surveyCount > 0;

  @override
  bool operator ==(Object other) =>
      other is FeedSummary &&
      other.totalReward == totalReward &&
      other.videoCount == videoCount &&
      other.surveyCount == surveyCount;

  @override
  int get hashCode => Object.hash(totalReward, videoCount, surveyCount);

  @override
  String toString() =>
      'FeedSummary(total: $totalReward, videos: $videoCount, surveys: $surveyCount)';
}

/// Totals and counts for [feed].
///
/// Rewards are summed as doubles and rounded once at the end, so
/// `[0.4, 0.4]` totals 1, not 0. Non-finite or negative rewards (never sent
/// by a healthy backend) count as 0 instead of poisoning the total.
FeedSummary summarizeFeed(List<Campaign> feed) {
  var total = 0.0;
  var videos = 0;
  var surveys = 0;
  for (final c in feed) {
    final r = c.rewardPerUser;
    if (r.isFinite && r > 0) total += r;
    if (c.hasVideo) {
      videos++;
    } else {
      surveys++;
    }
  }
  return FeedSummary(
    totalReward: total.round(),
    videoCount: videos,
    surveyCount: surveys,
  );
}

/// Caption under the hero amount: '2 видео · 1 судалгаа', or just the
/// non-zero part ('3 видео', '1 судалгаа'). Empty string for an empty feed.
String summaryCaption(FeedSummary s) {
  final parts = [
    if (s.videoCount > 0) '${s.videoCount} видео',
    if (s.surveyCount > 0) '${s.surveyCount} судалгаа',
  ];
  return parts.join(' · ');
}

/// The filter bar only appears when the feed mixes videos and surveys;
/// otherwise every tab but one would be empty.
bool shouldShowFilter(FeedSummary s) => s.hasBothKinds;

/// The filter actually applied: the user's choice while the bar is visible,
/// [FeedFilter.all] once a refresh leaves only one kind (the bar hides, so
/// the list must not stay stuck on an empty tab).
FeedFilter effectiveFilter(FeedFilter selected, FeedSummary s) =>
    shouldShowFilter(s) ? selected : FeedFilter.all;

/// Coarse time of day for the header greeting.
enum DayPart { morning, afternoon, evening, night }

/// 05:00-11:59 morning, 12:00-17:59 afternoon, 18:00-22:59 evening,
/// otherwise night.
DayPart dayPartOf(DateTime time) {
  final h = time.hour;
  if (h >= 5 && h < 12) return DayPart.morning;
  if (h >= 12 && h < 18) return DayPart.afternoon;
  if (h >= 18 && h < 23) return DayPart.evening;
  return DayPart.night;
}

/// Polite greeting for the header.
String greetingFor(DayPart part) => switch (part) {
      DayPart.morning => 'Өглөөний мэнд',
      DayPart.afternoon => 'Өдрийн мэнд',
      DayPart.evening => 'Оройн мэнд',
      DayPart.night => 'Сайн байна уу',
    };

/// Card call-to-action: watch a video, or fill in a survey.
String campaignCtaLabel(Campaign c) => c.hasVideo ? 'Үзэх' : 'Бөглөх';

/// Top-left chip text on a card: the video length, or 'Судалгаа'.
String campaignKindLabel(Campaign c) =>
    c.hasVideo ? formatDurationShort(c.durationSeconds) : 'Судалгаа';

/// One screen-reader sentence for a whole card, e.g.
/// 'Шинэ 5G багц. MobiCom. Видео, 45 сек. Урамшуулал +700 ₮'.
String campaignSemanticLabel(Campaign c) {
  final kind = c.hasVideo
      ? 'Видео, ${formatDurationShort(c.durationSeconds)}'
      : 'Судалгаа';
  final parts = [
    c.title.trim(),
    c.companyName.trim(),
    kind,
    'Урамшуулал ${formatTugrik(c.rewardPerUser, withSign: true)}',
  ].where((p) => p.isNotEmpty);
  return parts.join('. ');
}
