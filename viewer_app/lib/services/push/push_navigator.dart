import 'package:flutter/foundation.dart';

import '../../models/campaign.dart';
import 'campaign_link_resolver.dart';
import 'push_message_parser.dart';

/// What [PushNavigator] needs from the app shell (router + snackbar).
abstract class PushNavigationTarget {
  void push(String location, {Object? extra});
  void goHome();
  void showMessage(String text);
}

/// Opens the video or survey screen for a tapped campaign push.
///
/// Taps that arrive before the user is on Home (cold start: splash/login)
/// are held and replayed by [markReady], so the splash redirect can't
/// swallow them.
class PushNavigator {
  PushNavigator({
    required CampaignLinkResolver resolver,
    required PushNavigationTarget target,
    required this.videoRoute,
    required this.surveyRoute,
  })  : _resolver = resolver,
        _target = target;

  static const notFoundMessage = 'Энэ видео одоо байхгүй байна';
  static const loadFailedMessage = 'Сервертэй холбогдож чадсангүй';

  final CampaignLinkResolver _resolver;
  final PushNavigationTarget _target;
  final String videoRoute;
  final String surveyRoute;

  bool _ready = false;
  CampaignPush? _pending;

  Future<void> open(CampaignPush push) async {
    if (!_ready) {
      _pending = push;
      return;
    }
    Campaign? campaign;
    try {
      campaign = await _resolver.resolve(push);
    } catch (e) {
      debugPrint('[push] campaign lookup failed: $e');
      _target.showMessage(loadFailedMessage);
      return;
    }
    if (campaign == null) {
      _target.goHome();
      _target.showMessage(notFoundMessage);
      return;
    }
    final route = push.hasVideo ? videoRoute : surveyRoute;
    _target.push('$route/${campaign.id}', extra: campaign);
  }

  /// Home is on screen (user logged in): replay any held tap.
  Future<void> markReady() async {
    _ready = true;
    final p = _pending;
    _pending = null;
    if (p != null) await open(p);
  }

  /// Logged out: hold taps until the next Home.
  void markNotReady() {
    _ready = false;
    _pending = null;
  }
}
