import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/push/push_navigator.dart';
import 'app_router.dart';

/// Messenger used for app-level snackbars that have no BuildContext
/// (e.g. "campaign no longer available" after a push tap).
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// [PushNavigationTarget] backed by the app's go_router instance.
class RouterPushTarget implements PushNavigationTarget {
  const RouterPushTarget(this._router);

  final GoRouter _router;

  @override
  void push(String location, {Object? extra}) =>
      _router.push(location, extra: extra);

  @override
  void goHome() => _router.go(Routes.home);

  @override
  void showMessage(String text) {
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
