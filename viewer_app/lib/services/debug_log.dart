import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

/// Prints the line built by [message] in debug builds only.
///
/// `debugPrint` alone also prints in release builds, and exception texts can
/// carry server replies, phone numbers or tokens that anyone reading the
/// device log would see. [message] is a callback so a release build does not
/// even format the text. [enabled] and [printer] exist for tests.
void debugLog(
  String Function() message, {
  bool enabled = kDebugMode,
  void Function(String? line)? printer,
}) {
  if (!enabled) return;
  (printer ?? debugPrint)(message());
}
