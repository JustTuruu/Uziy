import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../viewer_service.dart';
import 'campaign_link_resolver.dart';
import 'device_registry.dart';
import 'firebase_push_client.dart';
import 'foreground_notifier.dart';
import 'push_message.dart';
import 'push_message_listener.dart';
import 'push_navigator.dart';
import 'push_service.dart';

/// App-wide composition root for push. Until [init] succeeds every method is
/// a no-op, so the app runs fine without Firebase config files.
class PushRuntime {
  PushRuntime._();
  static final PushRuntime instance = PushRuntime._();

  PushService? _service;
  PushNavigator? _navigator;

  /// Initialises Firebase and wires push. Never throws: on any failure
  /// (e.g. missing google-services.json / GoogleService-Info.plist) push is
  /// simply disabled.
  Future<void> init({
    required PushNavigationTarget target,
    required String videoRoute,
    required String surveyRoute,
  }) async {
    try {
      final platform = switch (defaultTargetPlatform) {
        TargetPlatform.android => PushPlatform.android,
        TargetPlatform.iOS => PushPlatform.ios,
        _ => null,
      };
      if (platform == null) return;

      await Firebase.initializeApp();
      final client = FirebasePushClient();
      if (platform == PushPlatform.ios) {
        await client.enableForegroundPresentation();
      }
      final notifier = LocalForegroundNotifier();
      await notifier.init();

      final navigator = PushNavigator(
        resolver: CampaignLinkResolver(ViewerService.instance.feed),
        target: target,
        videoRoute: videoRoute,
        surveyRoute: surveyRoute,
      );
      await PushMessageListener(
        client: client,
        notifier: notifier,
        navigator: navigator,
        showForeground: platform == PushPlatform.android,
      ).attach();

      _navigator = navigator;
      _service = PushService(
        client: client,
        registry: ViewerDeviceRegistry(),
        platform: platform,
      );
    } catch (e) {
      debugPrint('[push] disabled, Firebase unavailable: $e');
      _service = null;
      _navigator = null;
    }
  }

  /// The logged-in user reached Home: ask permission, register the token,
  /// and replay any notification tap held since cold start.
  Future<void> onHomeReached() async {
    await _service?.start();
    await _navigator?.markReady();
  }

  /// Call before the auth token is cleared.
  Future<void> onLogout() async {
    _navigator?.markNotReady();
    await _service?.stop();
  }
}
