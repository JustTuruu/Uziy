enum CampaignStatus { active, paused, completed }

class Campaign {
  final int id;
  final int companyId;
  final String companyName;
  final String videoUrl; // .m3u8 HLS manifest on Cloudflare R2
  final String? thumbnailUrl;
  final String title;
  final int durationSeconds;
  final double rewardPerUser; // ₮ received by viewer on completion
  final CampaignStatus status;

  const Campaign({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.title,
    required this.durationSeconds,
    required this.rewardPerUser,
    this.status = CampaignStatus.active,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] as int,
      companyId: json['company_id'] as int,
      companyName: json['company_name'] as String? ?? '',
      videoUrl: json['video_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      title: json['title'] as String? ?? '',
      durationSeconds: json['duration_seconds'] as int? ?? 30,
      rewardPerUser: (json['reward_per_user'] as num).toDouble(),
      status: CampaignStatus.values.firstWhere(
        (s) => s.name.toUpperCase() == (json['status'] as String).toUpperCase(),
        orElse: () => CampaignStatus.active,
      ),
    );
  }

  // Mock feed for UI development before the backend exists.
  static List<Campaign> mockFeed() => const [
        Campaign(
          id: 1,
          companyId: 100,
          companyName: 'MobiCom',
          videoUrl: '',
          title: 'Шинэ 5G багц - Танд хамгийн тохирсон',
          durationSeconds: 45,
          rewardPerUser: 700,
        ),
        Campaign(
          id: 2,
          companyId: 101,
          companyName: 'Golomt Bank',
          videoUrl: '',
          title: 'Оюутны зээл 0% хүүтэй',
          durationSeconds: 60,
          rewardPerUser: 500,
        ),
        Campaign(
          id: 3,
          companyId: 102,
          companyName: 'UniTel',
          videoUrl: '',
          title: 'Интернэт багцын шинэ хямдрал',
          durationSeconds: 30,
          rewardPerUser: 600,
        ),
      ];
}
