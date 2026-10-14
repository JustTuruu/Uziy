import 'push_message.dart';

/// Where a tapped push leads. Pattern: sealed variants, one per push type,
/// so [PushNavigator] handles every kind with an exhaustive switch.
sealed class PushLink {
  const PushLink();
}

/// Typed payload of a "new campaign" push.
class CampaignPush extends PushLink {
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

/// "Your payout request was decided" (approved or rejected): opens the
/// wallet, whose history shows the result.
class PayoutPush extends PushLink {
  const PayoutPush({required this.payoutId});

  final int payoutId;

  @override
  bool operator ==(Object other) =>
      other is PayoutPush && other.payoutId == payoutId;

  @override
  int get hashCode => payoutId.hashCode;

  @override
  String toString() => 'PayoutPush($payoutId)';
}

/// Turns raw FCM data into a [PushLink]. Unknown or malformed payloads
/// yield null so they are ignored rather than crashing the app.
class PushMessageParser {
  const PushMessageParser();

  static const campaignType = 'CAMPAIGN';
  static const payoutType = 'PAYOUT';

  PushLink? parseData(Map<String, String> data) => switch (data['type']) {
        campaignType => _campaign(data),
        payoutType => _payout(data),
        _ => null,
      };

  CampaignPush? _campaign(Map<String, String> data) {
    final id = _positiveId(data['campaignId']);
    if (id == null) return null;
    // Missing hasVideo defaults to a video campaign, like Campaign.fromJson.
    final hasVideo = (data['hasVideo'] ?? 'true').toLowerCase() != 'false';
    return CampaignPush(campaignId: id, hasVideo: hasVideo);
  }

  PayoutPush? _payout(Map<String, String> data) {
    final id = _positiveId(data['payoutId']);
    return id == null ? null : PayoutPush(payoutId: id);
  }

  static int? _positiveId(String? raw) {
    final id = int.tryParse(raw ?? '');
    return id == null || id <= 0 ? null : id;
  }

  PushLink? parse(PushMessage message) => parseData(message.data);
}
