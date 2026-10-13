import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/screens/auth/forgot_password_screen.dart';
import 'package:viewer_app/screens/auth/otp_logic.dart';
import 'package:viewer_app/screens/auth/reset_password_screen.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/widgets/ui.dart';

import '../../support/fake_api.dart';

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

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

  group('ForgotPasswordScreen', () {
    testWidgets('rejects a short phone without calling the backend',
        (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, const ForgotPasswordScreen());

      await tester.enterText(find.byType(TextField), '8811');
      await tester.tap(find.text(kForgotSendLabel));
      await tester.pump();

      expect(find.text('Утасны дугаараа шалгана уу'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('asks for a reset code and moves to the code page',
        (tester) async {
      final api = FakeApi.install((_) => const FakeReply(204));
      await _pump(tester, const ForgotPasswordScreen());

      await tester.enterText(find.byType(TextField), '88112233');
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

      await tester.enterText(find.byType(TextField), '88112233');
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
