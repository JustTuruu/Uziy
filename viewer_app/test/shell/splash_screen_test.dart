import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/screens/splash_screen.dart';
import 'package:viewer_app/widgets/ui.dart';

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// Stubs flutter_secure_storage so AuthService.readToken() returns [token].
void _stubToken(WidgetTester tester, String? token) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _secureStorage,
    (call) async => call.method == 'read' ? token : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _secureStorage,
      null,
    ),
  );
}

/// Pumps the real SplashScreen inside a minimal router whose /login and
/// /home destinations are placeholders.
Future<void> _pumpSplash(WidgetTester tester, {bool reduceMotion = false}) {
  final router = GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const Scaffold(body: Text('login-page')),
      ),
      GoRoute(
        path: Routes.home,
        builder: (_, __) => const Scaffold(body: Text('home-page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.dark(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
    ),
  );
}

double _logoOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(UziyLogo),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

double _logoScale(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find
          .ancestor(
            of: find.byType(UziyLogo),
            matching: find.byType(ScaleTransition),
          )
          .first,
    )
    .scale
    .value;

void main() {
  testWidgets('shows only the logo: no text and no spinner', (tester) async {
    _stubToken(tester, null);
    await _pumpSplash(tester);

    expect(find.byType(UziyLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    // Shared hero tag so the logo can fly to the auth screens.
    expect(
      find.byWidgetPredicate(
        (w) => w is Hero && w.tag == SplashScreen.logoHeroTag,
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
  });

  testWidgets('logo scales and fades in, then keeps breathing', (
    tester,
  ) async {
    _stubToken(tester, null);
    await _pumpSplash(tester);

    expect(_logoOpacity(tester), lessThan(0.05));
    expect(_logoScale(tester), closeTo(0.85, 0.01));

    await tester.pump(const Duration(milliseconds: 700));
    expect(_logoOpacity(tester), 1);
    expect(_logoScale(tester), closeTo(1, 0.001));
    // The halo keeps animating while the splash is up.
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  });

  testWidgets('without a token it goes to /login after the minimum delay', (
    tester,
  ) async {
    _stubToken(tester, null);
    await _pumpSplash(tester);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('login-page'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    // pumpAndSettle only returns once the splash (and its repeating glow)
    // is gone, proving the animation is torn down on dispose.
    await tester.pumpAndSettle();
    expect(find.text('login-page'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('breathing is bounded: a stuck splash goes idle', (
    tester,
  ) async {
    // Token read that never answers (like an unmocked plugin in tests).
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _secureStorage,
      (call) => Completer<Object?>().future,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _secureStorage,
        null,
      ),
    );
    await _pumpSplash(tester);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.binding.hasScheduledFrame, isTrue);
    // Would time out if the glow repeated forever.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('with a saved token it goes to /home', (tester) async {
    _stubToken(tester, 'jwt-token');
    await _pumpSplash(tester);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text('home-page'), findsOneWidget);
    expect(find.text('login-page'), findsNothing);
  });

  testWidgets('reduce motion shows the settled logo with no animation', (
    tester,
  ) async {
    _stubToken(tester, null);
    await _pumpSplash(tester, reduceMotion: true);

    expect(_logoOpacity(tester), 1);
    expect(_logoScale(tester), 1);
    // Let the router finish its first-frame bookkeeping; after that nothing
    // on the splash should keep requesting frames.
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text('login-page'), findsOneWidget);
  });
}
