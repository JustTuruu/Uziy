import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/models/phone_verification.dart';
import 'package:viewer_app/models/register_draft.dart';
import 'package:viewer_app/models/user.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/screens/auth/phone_verify_logic.dart';
import 'package:viewer_app/screens/auth/phone_verify_screen.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/widgets/ui.dart';

import '../../support/fake_api.dart';

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

final _now = DateTime.utc(2026, 10, 13, 4);
final _expires = _now.add(const Duration(minutes: 5));

PhoneVerification _check(String id, String code) => PhoneVerification(
      id: id,
      phone: '88112233',
      shortcode: '144773',
      smsText: code,
      smsUri: 'sms:144773?body=$code',
      displayInstruction:
          'Та өөрийн 88112233 дугаараас 144773 дугаарт "$code" гэж SMS илгээнэ үү.',
      expiresAt: _expires,
    );

final _pending = PendingRegistration(
  draft: RegisterDraft(
    phone: '88112233',
    password: 'password1',
    lastName: 'Оюун-Эрдэнэ',
    firstName: 'Төрболд',
    gender: Gender.female,
    birthDate: DateTime(2000, 1, 2),
    city: 'Улаанбаатар',
  ),
  verification: _check('v1', '482916'),
);

const _authOk = FakeReply(201, {
  'token': 'jwt',
  'user': {
    'id': 1,
    'phoneNumber': '88112233',
    'role': 'VIEWER',
    'balance': 0,
    'isVerified': false,
  },
});

FakeReply _state(String status) => FakeReply(200, {
      'verificationId': 'v1',
      'status': status,
      'expiresAt': _expires.toIso8601String(),
    });

FakeReply _startedReply(String id, String code) => FakeReply(201, {
      'verificationId': id,
      'phoneNumber': '88112233',
      'shortcode': '144773',
      'smsText': code,
      'smsUri': 'sms:144773?body=$code',
      'displayInstruction': 'шинэ заавар $code',
      'status': 'PENDING',
      'expiresAt': _expires.toIso8601String(),
    });

/// Pumps the page over a stub page, inside a router that knows /home.
/// Never pumpAndSettle: the waiting spinner animates forever.
Future<void> _pump(
  WidgetTester tester, {
  SmsLauncher? launchSms,
  DateTime Function()? now,
}) async {
  tester.view.physicalSize = const Size(390, 1000) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/under',
    routes: [
      GoRoute(path: '/under', builder: (_, __) => const Text('under')),
      GoRoute(
        path: '/screen',
        builder: (_, __) => PhoneVerifyScreen(
          pending: _pending,
          launchSms: launchSms ?? (_) async => true,
          now: now ?? () => _now,
        ),
      ),
      GoRoute(path: Routes.home, builder: (_, __) => const Text('home-page')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  router.push('/screen');
  await _settle(tester);
}

/// Lets requests answer and the route animation finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _nextPoll(WidgetTester tester) async {
  await tester.pump(kPhoneVerifyPollInterval);
  await _settle(tester);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiService.instance.setAuthToken(null);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async => null);
  });
  tearDown(() {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
    ApiService.instance.setAuthToken(null);
  });

  testWidgets('shows the code, the short code and the instruction verbatim',
      (tester) async {
    FakeApi.install((_) => _state('PENDING'));
    await _pump(tester);

    expect(find.text('482916'), findsOneWidget);
    expect(find.text('144773'), findsOneWidget);
    expect(find.text(_pending.verification.displayInstruction), findsOneWidget);
    expect(find.text(kSmsCostNote), findsOneWidget);
    expect(find.text(kWaitingForSms), findsOneWidget);
  });

  testWidgets('the SMS button opens the pre-filled SMS link', (tester) async {
    FakeApi.install((_) => _state('PENDING'));
    final opened = <Uri>[];
    await _pump(tester, launchSms: (uri) async {
      opened.add(uri);
      return true;
    });

    await tester.tap(find.text(kSendSmsLabel));
    await tester.pump();

    expect(opened.single.toString(), 'sms:144773?body=482916');
  });

  testWidgets('when no SMS app opens, says how to send it by hand',
      (tester) async {
    FakeApi.install((_) => _state('PENDING'));
    await _pump(tester, launchSms: (_) async => false);

    await tester.tap(find.text(kSendSmsLabel));
    await _settle(tester);

    expect(find.text(kSmsAppFailed), findsOneWidget);
  });

  testWidgets(
      'polls every 3 s; PENDING then VERIFIED registers with the check and goes home',
      (tester) async {
    var polls = 0;
    final api = FakeApi.install((call) {
      if (call.path == '/auth/register/viewer') return _authOk;
      polls++;
      return _state(polls < 2 ? 'PENDING' : 'VERIFIED');
    });
    await _pump(tester);
    expect(api.calls, isEmpty, reason: 'no poll before the first interval');

    await _nextPoll(tester);
    expect(api.callsTo('/auth/phone-verifications/v1'), hasLength(1));
    expect(api.callsTo('/auth/register/viewer'), isEmpty);

    await _nextPoll(tester);
    final body = api.callsTo('/auth/register/viewer').single.body as Map;
    expect(body['verificationId'], 'v1');
    expect(body['phoneNumber'], '88112233');
    expect(body['gender'], 'FEMALE');
    expect(body['lastName'], 'Оюун-Эрдэнэ');
    expect(body['firstName'], 'Төрболд');
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('stops polling once verified', (tester) async {
    final api = FakeApi.install((call) => call.path == '/auth/register/viewer'
        ? const FakeReply(503, {'message': 'түр алдаа'})
        : _state('VERIFIED'));
    await _pump(tester);

    await _nextPoll(tester);
    await _nextPoll(tester);
    await _nextPoll(tester);

    expect(api.callsTo('/auth/phone-verifications/v1'), hasLength(1));
    expect(find.text(kSendSmsLabel), findsNothing);
  });

  testWidgets('a retryable registration failure offers a retry that works',
      (tester) async {
    var registers = 0;
    final api = FakeApi.install((call) {
      if (call.path != '/auth/register/viewer') return _state('VERIFIED');
      registers++;
      return registers == 1
          ? const FakeReply(503, {'message': 'түр алдаа'})
          : _authOk;
    });
    await _pump(tester);
    await _nextPoll(tester);
    expect(find.text('түр алдаа'), findsOneWidget);

    await tester.tap(find.text(kRetryLabel));
    await _settle(tester);

    expect(api.callsTo('/auth/register/viewer'), hasLength(2));
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets(
      'EXPIRED hides the SMS button; a new code replaces the old and polling resumes',
      (tester) async {
    var expired = true;
    final api = FakeApi.install((call) {
      if (call.path == '/auth/phone-verifications') {
        return _startedReply('v2', '777111');
      }
      return _state(expired ? 'EXPIRED' : 'PENDING');
    });
    await _pump(tester);

    await _nextPoll(tester);
    expect(find.text(kCodeExpiredTitle), findsOneWidget);
    expect(find.text(kSendSmsLabel), findsNothing);

    expired = false;
    await tester.tap(find.text(kNewCodeLabel));
    await _settle(tester);

    expect(api.callsTo('/auth/phone-verifications').single.body,
        {'phoneNumber': '88112233', 'purpose': 'REGISTER'});
    expect(find.text('777111'), findsOneWidget);
    expect(find.text('482916'), findsNothing);
    expect(find.text('шинэ заавар 777111'), findsOneWidget);
    expect(find.text(kNewCodeReady), findsOneWidget);
    expect(find.text(kSendSmsLabel), findsOneWidget);

    await _nextPoll(tester);
    expect(api.callsTo('/auth/phone-verifications/v2'), hasLength(1));
  });

  testWidgets('a refused new code shows the backend message', (tester) async {
    FakeApi.install((call) => call.path == '/auth/phone-verifications'
        ? const FakeReply(429, {'message': 'Түр хүлээгээд дахин оролдоно уу'})
        : _state('EXPIRED'));
    await _pump(tester);
    await _nextPoll(tester);

    await tester.tap(find.text(kNewCodeLabel));
    await _settle(tester);

    expect(find.text('Түр хүлээгээд дахин оролдоно уу'), findsOneWidget);
    expect(find.text(kNewCodeLabel), findsOneWidget);
  });

  testWidgets('a check the backend refuses at registration asks for a new code',
      (tester) async {
    FakeApi.install((call) => call.path == '/auth/register/viewer'
        ? const FakeReply(400, {'message': 'баталгаажаагүй'})
        : _state('VERIFIED'));
    await _pump(tester);

    await _nextPoll(tester);

    expect(find.text('баталгаажаагүй'), findsOneWidget);
    expect(find.text(kNewCodeLabel), findsOneWidget);
  });

  testWidgets('still pending past the deadline gives up by itself',
      (tester) async {
    FakeApi.install((_) => _state('PENDING'));
    await _pump(
      tester,
      now: () => _expires.add(const Duration(minutes: 1)),
    );

    await _nextPoll(tester);

    expect(find.text(kCodeExpiredTitle), findsOneWidget);
  });
}
