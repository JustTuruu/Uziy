import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_message.dart';

/// Shows a system notification for a message received in the foreground
/// and reports taps on it.
abstract class ForegroundNotifier {
  Future<void> init();
  Future<void> show(PushMessage message);

  /// Data map of the tapped notification.
  Stream<Map<String, String>> get taps;
}

class LocalForegroundNotifier implements ForegroundNotifier {
  LocalForegroundNotifier([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'campaigns';
  static const channelName = 'Шинэ видео, судалгаа';
  static const channelDescription = 'Танд тохирсон шинэ видео, судалгааны мэдэгдэл';

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<Map<String, String>>.broadcast();
  int _nextId = 0;

  @override
  Stream<Map<String, String>> get taps => _taps.stream;

  @override
  Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final data = decodePayload(r.payload);
        if (data != null) _taps.add(data);
      },
    );
  }

  @override
  Future<void> show(PushMessage message) {
    return _plugin.show(
      id: _nextId++,
      title: message.title,
      body: message.body,
      payload: jsonEncode(message.data),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Visible for testing.
  static Map<String, String>? decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return null;
    }
  }
}
