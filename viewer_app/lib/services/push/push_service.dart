import 'dart:async';

import 'package:flutter/foundation.dart';

import 'device_registry.dart';
import 'push_client.dart';
import 'push_message.dart';

/// Facade: permission -> FCM token -> backend registration, token refresh,
/// and unregistration on logout. Never throws to the UI.
class PushService {
  PushService({
    required PushClient client,
    required DeviceRegistry registry,
    required PushPlatform platform,
  })  : _client = client,
        _registry = registry,
        _platform = platform;

  final PushClient _client;
  final DeviceRegistry _registry;
  final PushPlatform _platform;

  StreamSubscription<String>? _refreshSub;
  String? _token;
  bool _started = false;

  /// Call once the user is logged in and on Home. Idempotent.
  Future<void> start() async {
    if (_started || !_client.isAvailable) return;
    _started = true;
    try {
      final permission = await _client.requestPermission();
      if (permission != PushPermission.granted) {
        _started = false; // ask again on the next Home visit
        return;
      }
      final token = await _client.getToken();
      if (token != null && token.isNotEmpty) await _register(token);
      _refreshSub = _client.onTokenRefresh.listen(_register);
    } catch (e) {
      debugPrint('[push] start failed: $e');
      _started = false;
    }
  }

  /// Best-effort: removes this device from the backend. Must be called
  /// BEFORE the auth token is cleared; never throws, so it can't block logout.
  Future<void> stop() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    final token = _token;
    _token = null;
    _started = false;
    if (token == null) return;
    try {
      await _registry.unregister(token);
    } catch (e) {
      debugPrint('[push] unregister failed: $e');
    }
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await _registry.register(token, _platform);
    } catch (e) {
      debugPrint('[push] register failed: $e');
    }
  }
}
