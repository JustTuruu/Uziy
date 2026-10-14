import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/ui.dart';

Widget _host({required bool reduce, required bool big, Duration? duration}) =>
    MaterialApp(
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: app!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => ReducibleAnimatedSize(
            duration:
                duration ?? AppMotion.duration(context, AppDurations.normal),
            child: SizedBox(height: big ? 80 : 0, width: 100),
          ),
        ),
      ),
    );

void main() {
  testWidgets('animates the size change normally', (tester) async {
    await tester.pumpWidget(_host(reduce: false, big: false));
    await tester.pumpWidget(_host(reduce: false, big: true));
    expect(find.byType(AnimatedSize), findsOneWidget);
    await tester.pumpAndSettle();
  });

  /// Regression (2026-10-14): with reduce-motion on, ticking the terms box on
  /// the register form (and the survey's back button / submit error) threw
  /// "RenderAnimatedSize was mutated in its own performLayout".
  testWidgets('under reduce-motion it jumps, and never throws', (tester) async {
    await tester.pumpWidget(_host(reduce: true, big: false));
    await tester.pumpWidget(_host(reduce: true, big: true));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(AnimatedSize), findsNothing);
    expect(tester.getSize(find.byType(SizedBox).last).height, 80);
  });

  testWidgets('a zero duration also jumps', (tester) async {
    await tester
        .pumpWidget(_host(reduce: false, big: false, duration: Duration.zero));
    await tester
        .pumpWidget(_host(reduce: false, big: true, duration: Duration.zero));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(AnimatedSize), findsNothing);
  });
}
