import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keeps a screen's data fresh without a pull-to-refresh: reloads when the
/// app comes back to the foreground and, while [polling] is on, every
/// [interval]. The timer stops while the app is in the background.
///
/// Pattern: Observer — listens to the app lifecycle and calls [onRefresh].
class AutoRefresher {
  AutoRefresher({
    required this.onRefresh,
    this.interval = defaultInterval,
  }) {
    _lifecycle = AppLifecycleListener(
      onResume: _resumed,
      onHide: _hidden,
    );
  }

  /// Short enough that an admin's decision shows up while the viewer is
  /// still looking; long enough not to load the server.
  static const Duration defaultInterval = Duration(seconds: 10);

  final Future<void> Function() onRefresh;
  final Duration interval;

  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  bool _polling = false;
  bool _foreground = true;
  bool _busy = false;
  bool _disposed = false;

  bool get isPolling => _timer != null;

  /// Turn the periodic reload on (e.g. a request is waiting for a decision)
  /// or off.
  set polling(bool value) {
    if (_disposed || value == _polling) return;
    _polling = value;
    value && _foreground ? _startTimer() : _stopTimer();
  }

  void _hidden() {
    _foreground = false;
    _stopTimer();
  }

  void _resumed() {
    _foreground = true;
    refresh();
    if (_polling) _startTimer();
  }

  /// Runs [onRefresh] unless one is already in flight.
  Future<void> refresh() async {
    if (_disposed || _busy) return;
    _busy = true;
    try {
      await onRefresh();
    } finally {
      _busy = false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _lifecycle.dispose();
  }
}
