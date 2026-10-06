import '../../models/campaign.dart';
import 'push_message_parser.dart';

/// Finds the real [Campaign] a push points at, via the viewer feed (which
/// already excludes watched / expired campaigns).
class CampaignLinkResolver {
  const CampaignLinkResolver(this._loadFeed);

  final Future<List<Campaign>> Function() _loadFeed;

  /// Null when the campaign is no longer in the feed. Network errors
  /// propagate to the caller.
  Future<Campaign?> resolve(CampaignPush push) async {
    final feed = await _loadFeed();
    for (final c in feed) {
      if (c.id == push.campaignId) return c;
    }
    return null;
  }
}
