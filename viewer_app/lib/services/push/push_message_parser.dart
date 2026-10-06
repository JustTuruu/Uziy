import 'push_message.dart';

/// Typed payload of a "new campaign" push.
class CampaignPush {
  const CampaignPush({required this.campaignId, required this.hasVideo});

  final int campaignId;
  final bool hasVideo;

  @override
  bool operator ==(Object other) =>
      other is CampaignPush &&
      other.campaignId == campaignId &&
      other.hasVideo == hasVideo;

  @override
  int get hashCode => Object.hash(campaignId, hasVideo);

  @override
  String toString() => 'CampaignPush($campaignId, hasVideo: $hasVideo)';
}

/// Turns raw FCM data into a [CampaignPush]. Unknown or malformed payloads
/// yield null so they are ignored rather than crashing the app.
class PushMessageParser {
  const PushMessageParser();

  static const campaignType = 'CAMPAIGN';

  CampaignPush? parseData(Map<String, String> data) {
    if (data['type'] != campaignType) return null;
    final id = int.tryParse(data['campaignId'] ?? '');
    if (id == null || id <= 0) return null;
    // Missing hasVideo defaults to a video campaign, like Campaign.fromJson.
    final hasVideo = (data['hasVideo'] ?? 'true').toLowerCase() != 'false';
    return CampaignPush(campaignId: id, hasVideo: hasVideo);
  }

  CampaignPush? parse(PushMessage message) => parseData(message.data);
}
