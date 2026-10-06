/// Plain value object for an incoming push, independent of firebase_messaging
/// so everything above [PushClient] can be tested with fakes.
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, String> data;
}

/// Outcome of the OS notification-permission prompt.
enum PushPermission { granted, denied }

/// Platform label the backend stores with a device token.
enum PushPlatform {
  android('ANDROID'),
  ios('IOS');

  const PushPlatform(this.wire);

  /// Value sent in `POST /viewer/devices`.
  final String wire;
}
