import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/routes/app_router.dart';
import 'package:viewer_app/theme/app_theme.dart';

/// Regression: wrapping the ShellRoute navigator in an AnimatedSwitcher threw
/// `'_dependents.isEmpty': is not true` when switching tabs.
void main() {
  testWidgets('switching tabs in the main shell does not throw',
      (tester) async {
    final router = GoRouter(
      initialLocation: Routes.home,
      routes: appRouter.configuration.routes,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    for (final path in [Routes.wallet, Routes.profile, Routes.home]) {
      router.go(path);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'navigating to $path');
    }
  });

  /// Regression (2026-10-13): the shell's background was fixed to the light
  /// paper colour, showing behind the tabs in dark mode.
  testWidgets('the shell background follows the dark theme', (tester) async {
    final router = GoRouter(
      initialLocation: Routes.wallet,
      routes: appRouter.configuration.routes,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    );
    await tester.pump();

    final shell = tester.widgetList<Scaffold>(find.byType(Scaffold)).first;
    expect(shell.backgroundColor, const AppPalette(true).background);

    // The wallet tab starts a load; let its timers finish after unmounting.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
