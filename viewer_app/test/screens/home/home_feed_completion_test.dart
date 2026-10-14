import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/home/home_feed_screen.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/services/viewer_service.dart';
import 'package:viewer_app/theme/app_theme.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _campaign(int id, String title) => {
      'id': id,
      'title': title,
      'videoUrl': '',
      'durationSeconds': 45,
      'hasVideo': true,
      'rewardPerUser': 700,
      'companyName': 'MobiCom',
    };

/// A backend that drops a campaign from the feed once it is submitted,
/// and pays 700 ₮ for it.
class _Backend {
  final done = <int>{};
  double balance = 1000;
  late final FakeApi api = FakeApi.install((call) {
    if (call.path == '/viewer/feed') {
      return FakeReply(200, [
        for (final c in [
          _campaign(1, 'Шинэ 5G багц'),
          _campaign(2, 'Хадгаламж')
        ])
          if (!done.contains(c['id'])) c,
      ]);
    }
    if (call.path == '/viewer/me') {
      return FakeReply(200, {
        'id': 100,
        'phoneNumber': '88112233',
        'role': 'VIEWER',
        'balance': balance,
        'isVerified': false,
      });
    }
    final submit =
        RegExp(r'^/viewer/campaigns/(\d+)/submit$').firstMatch(call.path);
    if (submit != null) {
      final id = int.parse(submit.group(1)!);
      if (!done.add(id)) {
        return const FakeReply(
            409, {'message': 'Та энэ урамшууллыг аль хэдийн авсан байна'});
      }
      balance += 700;
      return FakeReply(200, {'rewardPaid': 700, 'newBalance': balance});
    }
    return const FakeReply(404);
  });
}

/// Home with a "survey" route pushed on top, like the real app: Home stays
/// alive underneath while the viewer answers.
Future<NavigatorState> _pumpHome(WidgetTester tester) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MaterialApp(
    navigatorKey: navigator,
    theme: AppTheme.light(),
    home: const Scaffold(body: HomeFeedScreen()),
  ));
  await tester.pumpAndSettle();
  return navigator.currentState!;
}

Future<void> _answerSurveyOnTop(
    WidgetTester tester, NavigatorState nav, int campaignId) async {
  nav.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('survey'))));
  await tester.pumpAndSettle();
  await tester.runAsync(() => ViewerService.instance.submitSurvey(
          campaignId: campaignId,
          answers: const {
            1: 'Тийм'
          }).catchError(
          (Object _) => const RewardResult(rewardPaid: 0, newBalance: 0)));
  nav.pop();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => ApiService.instance.setAuthToken('test-token'));
  tearDown(() => ApiService.instance.setAuthToken(null));

  testWidgets(
      'a finished campaign leaves the feed and the balance updates, '
      'without a manual refresh (regression)', (tester) async {
    final backend = _Backend()..api;
    final nav = await _pumpHome(tester);
    expect(find.text('Шинэ 5G багц', findRichText: true), findsWidgets);
    expect(find.text('1,000 ₮'), findsOneWidget);

    await _answerSurveyOnTop(tester, nav, 1);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.textContaining('5G', findRichText: true), findsNothing);
    expect(find.textContaining('Хадгаламж', findRichText: true), findsWidgets);
    expect(find.text('1,700 ₮'), findsOneWidget);
    expect(backend.done, {1});
  });

  testWidgets('a campaign the server says is already rewarded also leaves',
      (tester) async {
    final backend = _Backend()..api;
    final nav = await _pumpHome(tester);
    // Completed elsewhere (another device) but still on this screen.
    backend.done.add(1);

    await _answerSurveyOnTop(tester, nav, 1);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.textContaining('5G', findRichText: true), findsNothing);
  });
}
