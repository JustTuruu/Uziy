import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/models/register_draft.dart';
import 'package:viewer_app/models/user.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/screens/auth/forgot_password_screen.dart';
import 'package:viewer_app/screens/auth/otp_logic.dart';
import 'package:viewer_app/screens/auth/otp_verify_screen.dart';
import 'package:viewer_app/screens/auth/reset_password_screen.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/widgets/ui.dart';

import '../../support/fake_api.dart';

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

final _draft = RegisterDraft(
  phone: '88112233',
  password: 'password1',
  gender: Gender.male,
  birthDate: DateTime(2000, 1, 2),
  city: 'Улаанбаатар',
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

/// Pumps [screen] as the top page of a router that also knows /home and
/// /login as plain labelled pages.
Future<GoRouter> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 900) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/under',
    routes: [
      GoRoute(path: '/under', builder: (_, __) => const Text('under')),
      GoRoute(path: '/screen', builder: (_, __) => screen),
      GoRoute(path: Routes.home, builder: (_, __) => const Text('home-page')),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const Scaffold(body: Text('login-page')),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, state) =>
            Text('reset-page ${state.extra}', textDirection: TextDirection.ltr),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
  router.push('/screen');
  await tester.pumpAndSettle();
  return router;
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField).first, code);
  await tester.pump();
}

List<String?> _digits(WidgetTester tester) =>
    tester.widgetList<OtpBox>(find.byType(OtpBox)).map((b) => b.digit).toList();

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

  group('OtpVerifyScreen', () {
    testWidgets('names the phone and starts the resend lock', (tester) async {
      FakeApi.install((_) => _authOk);
      await _pump(tester, OtpVerifyScreen(draft: _draft));

      expect(find.text(otpSubtitle('+976 8811 2233')), findsOneWidget);
      expect(find.text(resendLabel(kOtpResendSeconds)), findsOneWidget);
      expect(find.byType(OtpBox), findsNWidgets(6));
    });

    testWidgets(
        'a full code registers with the form and the code, then goes home',
        (tester) async {
      final api = FakeApi.install((_) => _authOk);
      await _pump(tester, OtpVerifyScreen(draft: _draft));

      await _enterCode(tester, '123456');
      await tester.pumpAndSettle();

      final call = api.callsTo('/auth/register/viewer').single;
      final body = call.body as Map;
      expect(body['phoneNumber'], '88112233');
      expect(body['otpCode'], '123456');
      expect(body['city'], 'Улаанбаатар');
      expect(find.text('home-page'), findsOneWidget);
    });

    testWidgets('a wrong code shows the error, empties the boxes and stays',
        (tester) async {
      FakeApi.install(
        (_) => const FakeReply(
            400, {'message': 'Код буруу эсвэл хугацаа дууссан байна'}),
      );
      await _pump(tester, OtpVerifyScreen(draft: _draft));

      await _enterCode(tester, '000000');
      await tester.pumpAndSettle();

      expect(
          find.text('Код буруу эсвэл хугацаа дууссан байна'), findsOneWidget);
      expect(_digits(tester), everyElement(isNull));
      expect(
        tester.widgetList<OtpBox>(find.byType(OtpBox)).every((b) => b.error),
        isTrue,
      );
      expect(find.text('home-page'), findsNothing);
    });

    testWidgets('typing again clears the error', (tester) async {
      FakeApi.install((_) => const FakeReply(400, {'message': 'Код буруу'}));
      await _pump(tester, OtpVerifyScreen(draft: _draft));
      await _enterCode(tester, '000000');
      await tester.pumpAndSettle();
      expect(find.text('Код буруу'), findsOneWidget);

      await _enterCode(tester, '1');
      await tester.pump();

      expect(find.text('Код буруу'), findsNothing);
    });

    testWidgets('the button with an incomplete code asks for six digits',
        (tester) async {
      final api = FakeApi.install((_) => _authOk);
      await _pump(tester, OtpVerifyScreen(draft: _draft));

      await _enterCode(tester, '123');
      await tester.tap(find.text(kOtpConfirmLabel));
      await tester.pump();

      expect(find.text(kOtpIncomplete), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('resend is locked for a minute, then asks for a new code',
        (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, OtpVerifyScreen(draft: _draft));

      await tester.tap(find.text(resendLabel(kOtpResendSeconds)));
      await tester.pump();
      expect(api.calls, isEmpty);

      await tester.pump(const Duration(seconds: kOtpResendSeconds));
      expect(find.text(kOtpResendLabel), findsOneWidget);

      await tester.tap(find.text(kOtpResendLabel));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      final call = api.callsTo('/auth/otp/request').single;
      expect(call.body, {'phoneNumber': '88112233', 'purpose': 'REGISTER'});
      expect(find.text(kOtpResent), findsOneWidget);
      expect(find.text(resendLabel(kOtpResendSeconds)), findsOneWidget);
    });

    testWidgets('a refused resend shows the backend message', (tester) async {
      FakeApi.install(
        (_) => const FakeReply(429, {'message': 'Хэт олон код хүссэн байна'}),
      );
      await _pump(tester, OtpVerifyScreen(draft: _draft));
      await tester.pump(const Duration(seconds: kOtpResendSeconds));

      await tester.tap(find.text(kOtpResendLabel));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('Хэт олон код хүссэн байна'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('rejects a short phone without calling the backend',
        (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, const ForgotPasswordScreen());

      await tester.enterText(find.byType(TextFormField), '8811');
      await tester.tap(find.text(kForgotSendLabel));
      await tester.pump();

      expect(find.text('Утасны дугаараа шалгана уу'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('asks for a reset code and moves to the code page',
        (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, const ForgotPasswordScreen());

      await tester.enterText(find.byType(TextFormField), '88112233');
      await tester.tap(find.text(kForgotSendLabel));
      await tester.pumpAndSettle();

      expect(api.callsTo('/auth/otp/request').single.body, {
        'phoneNumber': '88112233',
        'purpose': 'PASSWORD_RESET',
      });
      expect(find.text('reset-page 88112233'), findsOneWidget);
    });

    testWidgets('a rate-limit answer is shown and the page stays',
        (tester) async {
      FakeApi.install(
        (_) => const FakeReply(
            429, {'message': 'Түр хүлээгээд дахин оролдоно уу'}),
      );
      await _pump(tester, const ForgotPasswordScreen());

      await tester.enterText(find.byType(TextFormField), '88112233');
      await tester.tap(find.text(kForgotSendLabel));
      await tester.pumpAndSettle();

      expect(find.text('Түр хүлээгээд дахин оролдоно уу'), findsOneWidget);
      expect(find.textContaining('reset-page'), findsNothing);
    });
  });

  group('ResetPasswordScreen', () {
    Future<void> fill(WidgetTester tester, String code, String password) async {
      await _enterCode(tester, code);
      await tester.enterText(find.byType(TextFormField), password);
      await tester.pump();
    }

    testWidgets('sends phone, code and new password, then returns to login',
        (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, const ResetPasswordScreen(phone: '88112233'));

      await fill(tester, '123456', 'new-password');
      await tester.tap(find.text(kResetSubmitLabel));
      await tester.pumpAndSettle();

      expect(api.callsTo('/auth/password/reset').single.body, {
        'phoneNumber': '88112233',
        'code': '123456',
        'newPassword': 'new-password',
      });
      expect(find.text('login-page'), findsOneWidget);
      expect(find.text(kResetDone), findsOneWidget);
    });

    testWidgets('a short password is refused before any request',
        (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, const ResetPasswordScreen(phone: '88112233'));

      await fill(tester, '123456', '123');
      await tester.tap(find.text(kResetSubmitLabel));
      await tester.pump();

      expect(find.text('Дор хаяж 6 тэмдэгт'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('an incomplete code is refused before any request',
        (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, const ResetPasswordScreen(phone: '88112233'));

      await fill(tester, '12', 'new-password');
      await tester.tap(find.text(kResetSubmitLabel));
      await tester.pump();

      expect(find.text(kOtpIncomplete), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('a wrong code shows the error and empties the boxes',
        (tester) async {
      FakeApi.install((_) => const FakeReply(400, {'message': 'Код буруу'}));
      await _pump(tester, const ResetPasswordScreen(phone: '88112233'));

      await fill(tester, '000000', 'new-password');
      await tester.tap(find.text(kResetSubmitLabel));
      await tester.pumpAndSettle();

      expect(find.text('Код буруу'), findsOneWidget);
      expect(_digits(tester), everyElement(isNull));
      expect(find.text('login-page'), findsNothing);
    });
  });
}
