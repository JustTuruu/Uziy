import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer_app/app.dart';

void main() {
  testWidgets('App boots — splash renders the logo without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ViewerApp()));
    await tester.pump();

    // Splash shows the logo Image asset — the only content on the splash
    // screen after we removed the title / tagline / spinner. Confirms the
    // widget tree renders end-to-end without exceptions.
    expect(find.byType(Image), findsWidgets);

    // Drain the 1.2s splash timer so pumpWidget teardown doesn't complain
    // about a pending Timer, then let the router settle.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
