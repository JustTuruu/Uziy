import 'dart:async';

import 'foreground_notifier.dart';
import 'push_client.dart';
import 'push_message.dart';
import 'push_message_parser.dart';
import 'push_navigator.dart';

/// Wires incoming pushes to behaviour: foreground messages -> local
/// notification (Android), every kind of tap -> [PushNavigator].
class PushMessageListener {
  PushMessageListener({
    required PushClient client,
    required ForegroundNotifier notifier,
    required PushNavigator navigator,
    required this.showForeground,
    PushMessageParser parser = const PushMessageParser(),
  })  : _client = client,
        _notifier = notifier,
        _navigator = navigator,
        _parser = parser;

  final PushClient _client;
  final ForegroundNotifier _notifier;
  final PushNavigator _navigator;
  final PushMessageParser _parser;

  /// True on Android, where FCM does not display foreground messages itself.
  final bool showForeground;

  final _subs = <StreamSubscription<dynamic>>[];

  Future<void> attach() async {
    if (!_client.isAvailable) return;
    _subs
      ..add(_client.onMessage.listen(_onForeground))
      ..add(_client.onMessageOpenedApp.listen(_onTap))
      ..add(_notifier.taps.listen(
        (data) => _open(_parser.parseData(data)),
      ));
    final initial = await _client.getInitialMessage();
    if (initial != null) _onTap(initial);
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  void _onForeground(PushMessage m) {
    if (!showForeground) return;
    _notifier.show(m);
  }

  void _onTap(PushMessage m) => _open(_parser.parse(m));

  void _open(CampaignPush? push) {
    if (push != null) _navigator.open(push);
  }
}
