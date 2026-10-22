import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/models/password_reset.dart';
import 'package:viewer_app/models/phone_verification.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/screens/auth/auth_widgets.dart';
import 'package:viewer_app/screens/auth/forgot_password_screen.dart';
import 'package:viewer_app/screens/auth/phone_verify_logic.dart';
import 'package:viewer_app/screens/auth/phone_verify_screen.dart';
import 'package:viewer_app/screens/auth/reset_password_screen.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/widgets/ui.dart';

import '../../support/fake_api.dart';

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

final _now = DateTime.utc(2026, 10, 14, 4);
final _expires = _now.add(const Duration(minutes: 5));

final _check = PhoneVerification(
  id: 'r1',
  phone: '88112233',
  shortcode: '144773',
  smsText: '482916',
  smsUri: 'sms:144773?body=482916',
  displayInstruction:
      'Та өөрийн 88112233 дугаараас 144773 дугаарт "482916" гэж SMS илгээнэ үү.',
  expiresAt: _expires,
);

final _reset = PendingPasswordReset(phone: '88112233', verification: _check);

FakeReply _started() => FakeReply(201, {
      'verificationId': 'r1',
      'phoneNumber': '88112233',
      'shortcode': '144773',
      'smsText': '482916',
      'smsUri': 'sms:144773?body=482916',
      'displayInstruction': 'заавар',
      'status': 'PENDING',
      'expiresAt': _expires.toIso8601String(),
    });

FakeReply _state(String status) => FakeReply(200, {
      'verificationId': 'r1',
      'status': status,
      'expiresAt': _expires.toIso8601String(),
    });

/// What the next pages received, so a test can check what travelled on.
final _arrived = <String, Object?>{};

/// Pumps [screen] over a stub page, in a router whose other auth pages just
/// record their `extra`. Never pumpAndSettle while a spinner may run.
Future<void> _pump(WidgetTester tester, Widget screen) async {
  _arrived.clear();
  tester.view.physicalSize = const Size(390, 1000) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  GoRoute stub(String path) => GoRoute(
        path: path,
        builder: (_, state) {
          _arrived[path] = state.extra;
          return Scaffold(body: Text('page $path'));
        },
      );
  final router = GoRouter(
    initialLocation: '/under',
    routes: [
      GoRoute(path: '/under', builder: (_, __) => const Text('under')),
      GoRoute(path: '/screen', builder: (_, __) => screen),
      stub(Routes.forgotVerify),
      stub(Routes.resetPassword),
      stub(Routes.login),
      stub(Routes.forgot),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  router.push('/screen');
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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
  });

  group('ForgotPasswordScreen', () {
    testWidgets('rejects a short phone without calling the backend',
        (tester) async {
      final api = FakeApi.install((_) => _started());
      await _pump(tester, const ForgotPasswordScreen());

      await tester.enterText(find.byType(TextField), '8811');
      await tester.tap(find.text(kForgotSendLabel));
      await _settle(tester);

      expect(api.calls, isEmpty);
    });

    testWidgets('opens a password-reset check and moves on to the SMS step',
        (tester) async {
      final api = FakeApi.install((_) => _started());
      await _pump(tester, const ForgotPasswordScreen());

      await tester.enterText(find.byType(TextField), '88112233');
      await tester.tap(find.text(kForgotSendLabel));
      await _settle(tester);

      expect(api.calls.single.path, '/auth/phone-verifications');
      expect(api.calls.single.body,
          {'phoneNumber': '88112233', 'purpose': 'PASSWORD_RESET'});
      final passed = _arrived[Routes.forgotVerify];
      expect(passed, isA<PendingPasswordReset>());
      expect((passed! as PendingPasswordReset).verification.id, 'r1');
    });

    testWidgets('a phone with no account is told so and stays here',
        (tester) async {
      FakeApi.install((_) =>
          const FakeReply(404, {'message': 'Энэ дугаараар бүртгэл олдсонгүй'}));
      await _pump(tester, const ForgotPasswordScreen());

      await tester.enterText(find.byType(TextField), '88112233');
      await tester.tap(find.text(kForgotSendLabel));
      await _settle(tester);

      expect(find.text('Энэ дугаараар бүртгэл олдсонгүй'), findsOneWidget);
      expect(_arrived.containsKey(Routes.forgotVerify), isFalse);
    });
  });

  group('PhoneVerifyScreen.passwordReset', () {
    Widget screen() => PhoneVerifyScreen.passwordReset(
          reset: _reset,
          launchSms: (_) async => true,
          now: () => _now,
        );

    testWidgets('explains the SMS is for the reset', (tester) async {
      FakeApi.install((_) => _state('PENDING'));
      await _pump(tester, screen());

      expect(find.text(kResetVerifySubtitle), findsOneWidget);
      expect(find.text('482916'), findsOneWidget);
    });

    testWidgets(
        'once the SMS arrived it opens the new-password page with '
        'the check, without registering anything', (tester) async {
      final api = FakeApi.install((_) => _state('VERIFIED'));
      await _pump(tester, screen());

      await tester.pump(kPhoneVerifyPollInterval);
      await _settle(tester);

      final passed = _arrived[Routes.resetPassword];
      expect(passed, isA<PendingPasswordReset>());
      expect((passed! as PendingPasswordReset).verification.id, 'r1');
      expect(api.callsTo('/auth/register/viewer'), isEmpty);
    });

    testWidgets('a new code is opened for the reset again, not for registering',
        (tester) async {
      final api = FakeApi.install(
          (call) => call.method == 'POST' ? _started() : _state('EXPIRED'));
      await _pump(tester, screen());

      await tester.pump(kPhoneVerifyPollInterval);
      await _settle(tester);
      await tester.tap(find.text(kNewCodeLabel));
      await _settle(tester);

      final start = api.callsTo('/auth/phone-verifications').single;
      expect(
          start.body, {'phoneNumber': '88112233', 'purpose': 'PASSWORD_RESET'});
    });
  });

  group('ResetPasswordScreen', () {
    Finder field(int i) => find.byType(TextField).at(i);

    Future<void> fill(WidgetTester tester, String first, String second) async {
      await tester.enterText(field(0), first);
      await tester.enterText(field(1), second);
    }

    Future<void> send(WidgetTester tester) async {
      await tester.ensureVisible(find.text(kResetSubmitLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kResetSubmitLabel));
      await _settle(tester);
    }

    testWidgets('sends the confirmed check with the new password, then login',
        (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, ResetPasswordScreen(reset: _reset));

      await fill(tester, 'newpass1', 'newpass1');
      await send(tester);

      expect(api.calls.single.path, '/auth/password/reset');
      expect(api.calls.single.body, {
        'phoneNumber': '88112233',
        'verificationId': 'r1',
        'newPassword': 'newpass1',
      });
      expect(find.text('page ${Routes.login}'), findsOneWidget);
      expect(find.text(kResetDone), findsOneWidget);
    });

    testWidgets('a too-short password is not sent', (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, ResetPasswordScreen(reset: _reset));

      await fill(tester, '12', '12');
      await send(tester);

      expect(api.calls, isEmpty);
    });

    // Owner, 2026-10-21: the new password is typed twice.
    testWidgets('asks for the password twice', (tester) async {
      FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, ResetPasswordScreen(reset: _reset));

      expect(find.byType(PasswordField), findsNWidgets(2));
      expect(find.text(kResetPasswordLabel), findsOneWidget);
      expect(find.text(kResetRepeatLabel), findsOneWidget);
    });

    testWidgets('a repeat that does not match is not sent', (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, ResetPasswordScreen(reset: _reset));

      await fill(tester, 'newpass1', 'newpass2');
      await send(tester);

      expect(api.calls, isEmpty);
      expect(find.text(AuthValidators.passwordMismatch), findsOneWidget);
    });

    testWidgets('an empty repeat is not sent', (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, ResetPasswordScreen(reset: _reset));

      await fill(tester, 'newpass1', '');
      await send(tester);

      expect(api.calls, isEmpty);
      expect(find.text(AuthValidators.passwordRepeatRequired), findsOneWidget);
    });

    testWidgets('each field has its own eye that shows the password',
        (tester) async {
      FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, ResetPasswordScreen(reset: _reset));
      bool hidden(int i) => tester.widget<TextField>(field(i)).obscureText;

      expect(hidden(0), isTrue);
      expect(hidden(1), isTrue);
      final eyes = find.bySemanticsLabel(PasswordField.showLabel);
      expect(eyes, findsNWidgets(2));

      await tester.tap(eyes.last);
      await tester.pump();
      expect(hidden(0), isTrue);
      expect(hidden(1), isFalse);

      await tester.tap(find.bySemanticsLabel(PasswordField.showLabel));
      await tester.pump();
      expect(hidden(0), isFalse);
    });

    testWidgets('a check that can no longer be used offers to start over',
        (tester) async {
      FakeApi.install((_) => const FakeReply(
          400, {'message': 'Утасны дугаар баталгаажаагүй байна'}));
      await _pump(tester, ResetPasswordScreen(reset: _reset));

      await fill(tester, 'newpass1', 'newpass1');
      await send(tester);

      expect(find.text('Утасны дугаар баталгаажаагүй байна'), findsOneWidget);
      await tester.ensureVisible(find.text(kResetStartOverLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kResetStartOverLabel));
      await _settle(tester);
      expect(find.text('page ${Routes.forgot}'), findsOneWidget);
    });
  });
}
