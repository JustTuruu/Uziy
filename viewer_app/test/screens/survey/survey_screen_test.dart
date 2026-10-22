import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/screens/survey/survey_screen.dart';
import 'package:viewer_app/screens/survey/survey_widgets.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/widgets/ui.dart';

import '../../support/fake_api.dart';

// The survey screen end to end over a fake backend: the money step of the
// app (spec §4C), so it is checked on the smallest phone with large text too.

const _campaignId = 5;
const _questionsPath = '/viewer/campaigns/$_campaignId/questions';
const _submitPath = '/viewer/campaigns/$_campaignId/submit';

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// Exactly what the backend's QuestionDto sends (no campaign id).
const _questions = FakeReply(200, [
  {
    'id': 11,
    'prompt':
        'Та манай шинэ багцыг хэрэглэж үзсэн үү? Хэрэглэсэн бол хэр удаж байна вэ?',
    'type': 'SINGLE_CHOICE',
    'options': [
      'Тийм, сүүлийн сард',
      'Үгүй, хараахан амжаагүй байна',
      'Мэдэхгүй'
    ],
    'required': true,
  },
  {
    'id': 12,
    'prompt': 'Юуг нь сайжруулах вэ?',
    'type': 'MULTI_CHOICE',
    'options': ['Үнэ', 'Хурд'],
    'required': true,
  },
  {
    'id': 13,
    'prompt': 'Нэмэлт санал',
    'type': 'TEXT',
    'options': <String>[],
    'required': false,
  },
]);

const _rewarded = FakeReply(200, {'rewardPaid': 700, 'newBalance': 5700});

/// Pumps the survey over a stub page, inside a router that knows /home.
/// Never pumpAndSettle: the reward sheet's confetti keeps animating.
Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/under',
    routes: [
      GoRoute(path: '/under', builder: (_, __) => const Text('under')),
      GoRoute(
        path: '/survey',
        builder: (_, __) => const SurveyScreen(campaignId: '$_campaignId'),
      ),
      GoRoute(path: Routes.home, builder: (_, __) => const Text('home-page')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
    ),
  );
  router.push('/survey');
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get _cta => find.byType(AdaptiveCtaButton);

Future<void> _tapCta(WidgetTester tester) async {
  await tester.tap(_cta);
  await _settle(tester);
}

Future<void> _tapOption(WidgetTester tester, String label) async {
  final option = find.text(label);
  // On a small phone with large text the options sit below the fold of the
  // question's lazy list, so scroll the way a viewer would.
  await tester.dragUntilVisible(
    option,
    find.byType(ListView).last,
    const Offset(0, -80),
  );
  await tester.pump();
  await tester.tap(option);
  await _settle(tester);
}

bool _ctaEnabled(WidgetTester tester) =>
    tester.widget<AdaptiveCtaButton>(_cta).onPressed != null;

/// Answers all three questions; leaves the screen on the last one.
Future<void> _answerAll(WidgetTester tester, {String? text}) async {
  await _tapOption(tester, 'Тийм, сүүлийн сард');
  await _tapCta(tester);
  await _tapOption(tester, 'Үнэ');
  await _tapOption(tester, 'Хурд');
  await _tapCta(tester);
  if (text != null) {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiService.instance.setAuthToken('jwt');
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async => null);
  });
  tearDown(() {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
    ApiService.instance.setAuthToken(null);
  });

  FakeReply backend(RecordedCall call, {FakeReply submit = _rewarded}) =>
      call.path == _questionsPath ? _questions : submit;

  for (final (name, size, scale) in [
    ('a regular phone', const Size(390, 844), 1.0),
    ('a 320pt phone at 1.3x text', const Size(320, 568), 1.3),
    ('a 320pt phone at 1.5x text', const Size(320, 568), 1.5),
  ]) {
    testWidgets('on $name the whole survey can be answered and paid',
        (tester) async {
      final api = FakeApi.install((c) => backend(c));
      await _pump(tester, size: size, textScale: scale);

      expect(_ctaEnabled(tester), isFalse, reason: 'a required question');
      await _answerAll(tester, text: 'Сайн байна,\n"хурдан" байвал\tгоё');
      await _tapCta(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Дууссан'), findsOneWidget);
      final body = api.callsTo(_submitPath).single.body as Map;
      final answers = {
        for (final a in body['answers'] as List)
          a['questionId']: jsonDecode(a['answerJson'] as String),
      };
      expect(answers, {
        11: 'Тийм, сүүлийн сард',
        12: ['Үнэ', 'Хурд'],
        13: 'Сайн байна,\n"хурдан" байвал\tгоё',
      });

      await tester.ensureVisible(find.text('Дууссан'));
      await tester.tap(find.text('Дууссан'));
      await _settle(tester);
      expect(find.text('home-page'), findsOneWidget);
    });
  }

  testWidgets('a multi-choice question with every pick undone blocks again',
      (tester) async {
    FakeApi.install((c) => backend(c));
    await _pump(tester);
    await _tapOption(tester, 'Тийм, сүүлийн сард');
    await _tapCta(tester);

    await _tapOption(tester, 'Үнэ');
    expect(_ctaEnabled(tester), isTrue);
    await _tapOption(tester, 'Үнэ');
    expect(_ctaEnabled(tester), isFalse);
  });

  testWidgets('the optional free-text question can be skipped', (tester) async {
    final api = FakeApi.install((c) => backend(c));
    await _pump(tester);
    await _answerAll(tester);
    expect(_ctaEnabled(tester), isTrue);

    await _tapCta(tester);

    final ids = [
      for (final a
          in (api.callsTo(_submitPath).single.body as Map)['answers'] as List)
        a['questionId'],
    ];
    expect(ids, [11, 12]);
  });

  testWidgets('an answer survives going back and forth', (tester) async {
    FakeApi.install((c) => backend(c));
    await _pump(tester);
    await _answerAll(tester, text: 'Өмнөх хариулт');

    await tester.tap(find.byType(StepBackButton));
    await _settle(tester);
    await tester.tap(_cta);
    await _settle(tester);

    expect(find.text('Өмнөх хариулт'), findsOneWidget);
  });

  testWidgets('a refused submit shows the backend message and can be retried',
      (tester) async {
    var refuse = true;
    final api = FakeApi.install(
      (c) => backend(
        c,
        submit: refuse
            ? const FakeReply(
                409, {'message': 'Та энэ судалгааг бөглөсөн байна'})
            : _rewarded,
      ),
    );
    await _pump(tester, size: const Size(320, 568), textScale: 1.3);
    await _answerAll(tester);

    await _tapCta(tester);
    expect(find.text('Та энэ судалгааг бөглөсөн байна'), findsOneWidget);
    expect(find.text('Дууссан'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(_ctaEnabled(tester), isTrue);

    refuse = false;
    await _tapCta(tester);
    expect(api.callsTo(_submitPath), hasLength(2));
    expect(find.text('Дууссан'), findsOneWidget);
  });

  testWidgets('a failed load says so in Mongolian and retries', (tester) async {
    var fail = true;
    // A proxy's 502 page: no JSON message to show.
    FakeApi.install((c) => fail ? const FakeReply(502) : backend(c));
    await _pump(tester, size: const Size(320, 568), textScale: 1.5);

    expect(find.text('Уучлаарай, алдаа гарлаа'), findsOneWidget);
    expect(find.textContaining('502'), findsNothing);
    expect(tester.takeException(), isNull);

    fail = false;
    await tester.tap(find.text('Дахин оролдох'));
    await _settle(tester);
    expect(find.text('Асуулт 1/3'), findsOneWidget);
  });

  testWidgets('a survey without questions offers the way home', (tester) async {
    FakeApi.install((_) => const FakeReply(200, <Object>[]));
    await _pump(tester);

    expect(find.text('Асуулт олдсонгүй'), findsOneWidget);
    await tester.tap(find.text('Нүүр хуудас руу буцах'));
    await _settle(tester);
    expect(find.text('home-page'), findsOneWidget);
  });
}
