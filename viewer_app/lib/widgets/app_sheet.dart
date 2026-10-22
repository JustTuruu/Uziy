import 'package:flutter/material.dart';

/// Opens a bottom sheet the way every sheet in the app should open.
///
/// Pattern: Facade — the one place that knows the sheet options. It always
/// pushes on the ROOT navigator: a tab screen's context belongs to the
/// ShellRoute's nested navigator, and a sheet pushed there is painted under
/// the floating tab bar (owner's screenshot, 2026-10-22: the bar hid the
/// add-name sheet's second field and button, and the scrim stopped at the
/// bar). The sheet sizes to its content ([isScrollControlled]) and its body
/// is wrapped in [AppSheetFrame], so builders never pad the keyboard or the
/// home indicator themselves.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => AppSheetFrame(child: builder(sheetContext)),
  );
}

/// Keeps a sheet's content above the keyboard and the home indicator.
///
/// The route's own safe area ([showModalBottomSheet]'s `useSafeArea`) covers
/// only the top and the sides; this adds the bottom. With the keyboard up the
/// bottom padding is already part of the keyboard inset, so it is not added
/// twice. The child should scroll (e.g. a [SingleChildScrollView]) so a small
/// phone with large text can still reach its last button.
class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(top: false, child: child),
    );
  }
}
