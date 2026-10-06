import 'push_message.dart';

/// Thin seam over firebase_messaging. [FirebasePushClient] is the real
/// implementation, [UnavailablePushClient] the no-op used when Firebase
/// could not be initialised (no config files yet).
abstract class PushClient {
  /// False when push cannot work in this build; callers then do nothing.
  bool get isAvailable;

  Future<PushPermission> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;

  /// Messages received while the app is in the foreground.
  Stream<PushMessage> get onMessage;

  /// Notification taps while the app was in the background.
  Stream<PushMessage> get onMessageOpenedApp;

  /// The notification that launched the app from the terminated state.
  Future<PushMessage?> getInitialMessage();
}

/// Used when Firebase failed to initialise: push becomes a silent no-op.
class UnavailablePushClient implements PushClient {
  const UnavailablePushClient();

  @override
  bool get isAvailable => false;

  @override
  Future<PushPermission> requestPermission() async => PushPermission.denied;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<PushMessage> get onMessage => const Stream.empty();

  @override
  Stream<PushMessage> get onMessageOpenedApp => const Stream.empty();

  @override
  Future<PushMessage?> getInitialMessage() async => null;
}
