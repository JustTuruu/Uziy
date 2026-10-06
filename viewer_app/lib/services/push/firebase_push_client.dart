import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_client.dart';
import 'push_message.dart';

/// [PushClient] backed by firebase_messaging. Only construct it after
/// `Firebase.initializeApp()` succeeded.
class FirebasePushClient implements PushClient {
  FirebasePushClient([FirebaseMessaging? messaging])
      : _fcm = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _fcm;

  @override
  bool get isAvailable => true;

  /// iOS only: show banner/sound while the app is open. (Android shows
  /// foreground messages through the local notifier instead.)
  Future<void> enableForegroundPresentation() =>
      _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

  @override
  Future<PushPermission> requestPermission() async {
    final s = await _fcm.requestPermission();
    return switch (s.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        PushPermission.granted,
      _ => PushPermission.denied,
    };
  }

  @override
  Future<String?> getToken() => _fcm.getToken();

  @override
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  @override
  Stream<PushMessage> get onMessage =>
      FirebaseMessaging.onMessage.map(_convert);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_convert);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final m = await _fcm.getInitialMessage();
    return m == null ? null : _convert(m);
  }

  static PushMessage _convert(RemoteMessage m) => PushMessage(
        title: m.notification?.title,
        body: m.notification?.body,
        data: m.data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      );
}
