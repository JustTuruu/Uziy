enum CampaignStatus { active, paused, completed }

/// Mirrors the backend's `FeedItemDto` (ViewerController.kt). `hasVideo`
/// distinguishes plain-video campaigns from survey-only ones — the viewer
/// app skips the video player and jumps straight to the survey for the
/// latter.
class Campaign {
  final int id;
  final String companyName;
  final String videoUrl; // .m3u8 HLS manifest on Cloudflare R2 (empty for survey-only)
  final String? thumbnailUrl;
  final String title;
  final int durationSeconds;
  final bool hasVideo;
  final double rewardPerUser;

  const Campaign({
    required this.id,
    required this.companyName,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.title,
    required this.durationSeconds,
    required this.rewardPerUser,
    this.hasVideo = true,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: (json['id'] as num).toInt(),
      companyName: json['companyName'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      title: json['title'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 30,
      rewardPerUser: (json['rewardPerUser'] as num).toDouble(),
      // Backend may not send hasVideo (older /viewer/feed shape) — default to
      // true (video campaign) unless explicitly false.
      hasVideo: json['hasVideo'] as bool? ?? true,
    );
  }

  /// Local-only fallback used by the router / tests when the backend is
  /// unreachable. In production the feed comes from GET /viewer/feed.
  static List<Campaign> mockFeed() => const [
        Campaign(
          id: 1,
          companyName: 'MobiCom',
          videoUrl: '',
          title: 'Шинэ 5G багц - Танд хамгийн тохирсон',
          durationSeconds: 45,
          rewardPerUser: 700,
        ),
        Campaign(
          id: 2,
          companyName: 'Golomt Bank',
          videoUrl: '',
          title: 'Оюутны зээл 0% хүүтэй',
          durationSeconds: 60,
          rewardPerUser: 500,
        ),
        Campaign(
          id: 3,
          companyName: 'UniTel',
          videoUrl: '',
          title: 'Судалгаа: Дуртай интернэт үйлчилгээ',
          durationSeconds: 0,
          rewardPerUser: 250,
          hasVideo: false,
        ),
      ];
}
