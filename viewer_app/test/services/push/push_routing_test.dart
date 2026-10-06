import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/models/campaign.dart';
import 'package:viewer_app/routes/app_router.dart';
import 'package:viewer_app/routes/router_push_target.dart';
import 'package:viewer_app/services/push/campaign_link_resolver.dart';
import 'package:viewer_app/services/push/push_message_parser.dart';
import 'package:viewer_app/services/push/push_navigator.dart';

import 'fakes.dart';

/// A tap payload drives a real GoRouter to the right route.
void main() {
  late GoRouter router;
  late PushNavigator navigator;

  Future<void> pumpApp(WidgetTester tester, List<Campaign> feed) async {
    router = GoRouter(
      initialLocation: Routes.home,
      routes: [
        GoRoute(
          path: Routes.home,
          builder: (_, __) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: '${Routes.video}/:id',
          builder: (_, s) => Scaffold(
            body: Text('VIDEO ${s.pathParameters['id']} '
                '${(s.extra as Campaign?)?.title}'),
          ),
        ),
        GoRoute(
          path: '${Routes.survey}/:id',
          builder: (_, s) =>
              Scaffold(body: Text('SURVEY ${s.pathParameters['id']}')),
        ),
      ],
    );
    navigator = PushNavigator(
      resolver: CampaignLinkResolver(() async => feed),
      target: RouterPushTarget(router),
      videoRoute: Routes.video,
      surveyRoute: Routes.survey,
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      scaffoldMessengerKey: rootMessengerKey,
    ));
    await navigator.markReady();
  }

  testWidgets('video payload opens the video screen with the campaign',
      (tester) async {
    await pumpApp(tester, [campaign(1)]);
    await navigator
        .open(const CampaignPush(campaignId: 1, hasVideo: true));
    await tester.pumpAndSettle();
    expect(find.text('VIDEO 1 T1'), findsOneWidget);
  });

  testWidgets('survey payload opens the survey screen', (tester) async {
    await pumpApp(tester, [campaign(2, hasVideo: false)]);
    await navigator
        .open(const CampaignPush(campaignId: 2, hasVideo: false));
    await tester.pumpAndSettle();
    expect(find.text('SURVEY 2'), findsOneWidget);
  });

  testWidgets('unknown campaign stays on Home with a snackbar',
      (tester) async {
    await pumpApp(tester, []);
    await navigator
        .open(const CampaignPush(campaignId: 9, hasVideo: true));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text(PushNavigator.notFoundMessage), findsOneWidget);
  });
}
