/// Mirrors the backend's `ViewHistoryItemDto` (GET /viewer/history): one
/// completed view with the reward it paid.
class ViewHistoryItem {
  final int campaignId;
  final String title;
  final String companyName;
  final double rewardPaid;
  final DateTime watchedAt;

  const ViewHistoryItem({
    required this.campaignId,
    required this.title,
    required this.companyName,
    required this.rewardPaid,
    required this.watchedAt,
  });

  factory ViewHistoryItem.fromJson(Map<String, dynamic> json) {
    return ViewHistoryItem(
      campaignId: (json['campaignId'] as num).toInt(),
      title: json['title'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      rewardPaid: (json['rewardPaid'] as num).toDouble(),
      // The backend sends an ISO-8601 instant with an offset; show it in the
      // viewer's own time zone.
      watchedAt: DateTime.parse(json['watchedAt'] as String).toLocal(),
    );
  }
}
