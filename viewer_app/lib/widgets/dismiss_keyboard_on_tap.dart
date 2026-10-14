import 'package:flutter/widgets.dart';

/// Closes the keyboard when the user taps anywhere that is not a field or a
/// control — the way iOS and Android apps usually behave — so nobody has to
/// scroll to get rid of it. Wraps the whole app once (see `app.dart`).
///
/// Buttons, fields and other tappable widgets win the gesture arena before
/// this outer recognizer, so they keep working (tapping another field moves
/// the focus there instead of closing the keyboard).
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
