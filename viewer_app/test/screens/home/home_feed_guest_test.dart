import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/screens/home/feed_widgets.dart';
import 'package:viewer_app/screens/home/guest_gate_sheet.dart';
import 'package:viewer_app/screens/home/home_feed_screen.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/widgets/ui.dart';

/// Answers /public/feed with one card and records every requested path.
class _GuestAdapter implements HttpClientAdapter {
  final requested = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.path);
    return ResponseBody.fromString(
      jsonEncode([
        {
          'id': 4,
          'title': 'Шинэ 5G багц',
          'videoUrl': '',
          'durationSeconds': 45,
          'hasVideo': true,
          'rewardPerUser': 700,
          'companyName': 'MobiCom',
        },
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A label inside the sign-in sheet (the header pill uses the same words).
Finder _inSheet(String text) =>
    find.descendant(of: find.byType(GuestGateSheet), matching: find.text(text));

void main() {
  late _GuestAdapter adapter;
  late GoRouter router;

  setUp(() {
    ApiService.instance.setAuthToken(null);
    adapter = _GuestAdapter();
    ApiService.instance.dio.httpClientAdapter = adapter;
    router = GoRouter(
      initialLocation: Routes.home,
      routes: [
        GoRoute(
          path: Routes.home,
          builder: (_, __) => const Scaffold(body: HomeFeedScreen()),
        ),
        GoRoute(
          path: Routes.login,
          builder: (_, state) => Scaffold(
            body: Text('login next=${state.uri.queryParameters['next']}'),
          ),
        ),
        GoRoute(
          path: Routes.register,
          builder: (_, state) => Scaffold(
            body: Text('register next=${state.uri.queryParameters['next']}'),
          ),
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a guest sees the public sample, not the personal feed',
      (tester) async {
    await pumpHome(tester);

    expect(adapter.requested, ['/public/feed']);
    expect(find.text('Шинэ 5G багц - Танд хамгийн тохирсон'), findsNothing);
    expect(find.byType(CampaignCard), findsOneWidget);
    expect(find.byType(GuestSignInPill), findsOneWidget);
    expect(find.byType(BalancePill), findsNothing);
  });

  testWidgets('tapping a card asks to sign in, then registers with next',
      (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byType(CampaignCard));
    await tester.pumpAndSettle();
    expect(find.text(kGuestGateTitle), findsOneWidget);

    await tester.tap(find.text(kGuestRegisterLabel));
    await tester.pumpAndSettle();

    expect(find.text('register next=/video/4'), findsOneWidget);
  });

  testWidgets('the sheet\'s Нэвтрэх opens login with the same next',
      (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byType(CampaignCard));
    await tester.pumpAndSettle();
    await tester.tap(_inSheet(kGuestLoginLabel));
    await tester.pumpAndSettle();

    expect(find.text('login next=/video/4'), findsOneWidget);
  });

  testWidgets('the header Нэвтрэх pill goes straight to login, no sheet',
      (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byType(GuestSignInPill));
    await tester.pumpAndSettle();

    expect(find.byType(GuestGateSheet), findsNothing);
    expect(find.text('login next=null'), findsOneWidget);
  });

  testWidgets('dismissing the sheet stays on home', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byType(CampaignCard));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(HomeFeedScreen), findsOneWidget);
    expect(find.textContaining('next='), findsNothing);
  });
}
