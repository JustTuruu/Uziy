import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/routes/app_router.dart';

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
}
