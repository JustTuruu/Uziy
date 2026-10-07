import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/models/campaign.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/routes/auth_gate.dart';
import 'package:viewer_app/routes/router_push_target.dart';

Campaign _campaign(int id, {bool hasVideo = true}) => Campaign(
      id: id,
      companyName: 'MobiCom',
      videoUrl: '',
      title: 't$id',
      durationSeconds: 30,
      rewardPerUser: 700,
      hasVideo: hasVideo,
    );

void main() {
  group('requiresAccount', () {
    test('wallet, profile and everything under them need an account', () {
      for (final l in [
        Routes.wallet,
        Routes.payout,
        Routes.profile,
        Routes.history,
        Routes.help,
        Routes.privacy,
      ]) {
        expect(requiresAccount(l), isTrue, reason: l);
      }
    });

    test('home, auth screens and campaign pages do not', () {
      for (final l in [
        Routes.splash,
        Routes.home,
        Routes.login,
        Routes.register,
        '${Routes.video}/3',
        '${Routes.survey}/3',
      ]) {
        expect(requiresAccount(l), isFalse, reason: l);
      }
    });
  });

  group('guestRedirect', () {
    test('sends a guest from the wallet to login, remembering the page', () {
      expect(
        guestRedirect(location: Routes.wallet, signedIn: false),
        '/login?next=%2Fwallet',
      );
    });

    test('remembers nested pages too', () {
      expect(
        guestRedirect(location: Routes.history, signedIn: false),
        '/login?next=%2Fprofile%2Fhistory',
      );
    });

    test('leaves a signed-in user alone', () {
      expect(guestRedirect(location: Routes.wallet, signedIn: true), isNull);
    });

    test('lets a guest see home and the auth screens', () {
      for (final l in [Routes.home, Routes.login, Routes.register]) {
        expect(guestRedirect(location: l, signedIn: false), isNull, reason: l);
      }
    });
  });

  group('authLocation', () {
    test('without next it is the bare route', () {
      expect(authLocation(Routes.register), '/register');
    });

    test('encodes next as a query parameter', () {
      expect(
        authLocation(Routes.login, next: '/video/5'),
        '/login?next=%2Fvideo%2F5',
      );
    });
  });

  group('parsePostAuth', () {
    test('nothing or garbage goes home', () {
      for (final n in [null, '', 'https://evil.example', 'video/5', '/other']) {
        expect(parsePostAuth(n), isA<GoHomeTarget>(), reason: '$n');
      }
    });

    test('a video route opens that video campaign', () {
      final t = parsePostAuth('/video/5') as OpenCampaignTarget;
      expect(t.campaignId, 5);
      expect(t.hasVideo, isTrue);
    });

    test('a survey route opens that survey campaign', () {
      final t = parsePostAuth('/survey/8') as OpenCampaignTarget;
      expect(t.campaignId, 8);
      expect(t.hasVideo, isFalse);
    });

    test('a campaign route with a non-numeric id goes home', () {
      expect(parsePostAuth('/video/abc'), isA<GoHomeTarget>());
    });

    test('an account page is opened as a location', () {
      final t = parsePostAuth('/wallet') as GoLocationTarget;
      expect(t.location, '/wallet');
    });
  });

  test('campaignRoute picks video or survey by hasVideo', () {
    expect(campaignRoute(_campaign(5)), '/video/5');
    expect(campaignRoute(_campaign(6, hasVideo: false)), '/survey/6');
  });

  group('finishAuth', () {
    final visited = <String>[];

    Future<void> run(
      WidgetTester tester, {
      String? next,
      Future<List<Campaign>> Function()? loadFeed,
    }) async {
      visited.clear();
      late BuildContext captured;
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, _) {
              captured = context;
              return const Scaffold(body: Text('start'));
            },
          ),
          for (final path in [
            Routes.home,
            Routes.wallet,
            '${Routes.video}/:id',
            '${Routes.survey}/:id',
          ])
            GoRoute(
              path: path,
              builder: (_, state) {
                visited.add(state.uri.path);
                return Scaffold(body: Text(state.uri.path));
              },
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => ScaffoldMessenger(
            key: rootMessengerKey,
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await finishAuth(captured, next, loadFeed: loadFeed);
      await tester.pumpAndSettle();
    }

    testWidgets('no next goes home', (tester) async {
      await run(tester);
      expect(find.text(Routes.home), findsOneWidget);
    });

    testWidgets('an account page is opened directly', (tester) async {
      await run(tester, next: Routes.wallet);
      expect(find.text(Routes.wallet), findsOneWidget);
    });

    testWidgets('a tapped campaign opens on top of home when it is in the feed',
        (tester) async {
      await run(
        tester,
        next: '/video/5',
        loadFeed: () async => [_campaign(4), _campaign(5)],
      );

      expect(find.text('/video/5'), findsOneWidget);
      expect(visited, contains(Routes.home));
    });

    testWidgets('a campaign missing from the feed stays home with a note',
        (tester) async {
      await run(
        tester,
        next: '/video/5',
        loadFeed: () async => [_campaign(4)],
      );

      expect(find.text(Routes.home), findsOneWidget);
      expect(find.text(kCampaignGoneMessage), findsOneWidget);
    });

    testWidgets('a failing feed also stays home with the note', (tester) async {
      await run(
        tester,
        next: '/video/5',
        loadFeed: () async => throw Exception('offline'),
      );

      expect(find.text(Routes.home), findsOneWidget);
      expect(find.text(kCampaignGoneMessage), findsOneWidget);
    });
  });
}
