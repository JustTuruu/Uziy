import 'dart:async';

/// A campaign the viewer has finished: its reward is paid, or the server
/// says it already was. [newBalance] is set when the server reported it.
class CampaignCompleted {
  const CampaignCompleted(this.campaignId, {this.newBalance});
  final int campaignId;
  final double? newBalance;
}

/// App-wide news about campaigns. Screens that stay alive under the video
/// and survey screens (Home) listen here instead of waiting for a manual
/// refresh.
///
/// Pattern: Observer — the service publishes, screens subscribe.
class CampaignEvents {
  CampaignEvents._();
  static final CampaignEvents instance = CampaignEvents._();

  final StreamController<CampaignCompleted> _completed =
      StreamController<CampaignCompleted>.broadcast();

  Stream<CampaignCompleted> get completed => _completed.stream;

  void publishCompleted(CampaignCompleted event) => _completed.add(event);
}
