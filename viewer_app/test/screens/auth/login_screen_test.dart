import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/services/api_error.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/screens/auth/auth_widgets.dart';
import 'package:viewer_app/screens/auth/login_screen.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/widgets/ui.dart';

import '../../support/fake_api.dart';

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

const _loginOk = FakeReply(200, {
  'token': 'jwt',
  'user': {
    'id': 1,
    'phoneNumber': '88112233',
    'role': 'VIEWER',
    'balance': 0,
    'isVerified': false,
  },
});

Future<void> _pump(
  WidgetTester tester, {
  double height = 844,
  double width = 390,
  double textScale = 1,
  String? next,
}) async {
  tester.view.physicalSize = Size(width, height) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.login,
    routes: [
      GoRoute(path: Routes.login, builder: (_, __) => LoginScreen(next: next)),
      GoRoute(path: Routes.home, builder: (_, __) => const Text('home-page')),
      GoRoute(
          path: Routes.forgot, builder: (_, __) => const Text('forgot-page')),
      GoRoute(
        path: Routes.register,
        builder: (_, state) =>
            Text('register-page next=${state.uri.queryParameters['next']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      // The falling coins loop forever; frozen coins let pumpAndSettle end.
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            disableAnimations: true, textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillAndSubmit(WidgetTester tester) async {
  // Native phone entry, then password.
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), '88112233');
  await tester.enterText(fields.at(1), 'password1');
  await tester.tap(find.widgetWithText(AppButton, 'Нэвтрэх'));
  await tester.pumpAndSettle();
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

  testWidgets('labels above, short placeholders and adornments inside',
      (tester) async {
    await _pump(tester);

    expect(find.text('Утасны дугаар'), findsOneWidget);
    expect(find.text('Нууц үг'), findsOneWidget);
    expect(find.text(kPhoneHint), findsOneWidget);
    expect(find.text(kPasswordHint), findsOneWidget);
    expect(find.text(kLoginSubtitle), findsOneWidget);
    expect(find.byIcon(AppIcons.phone), findsOneWidget);
    expect(find.byIcon(AppIcons.lock), findsOneWidget);
    expect(find.text('Нэвтрэх'), findsNWidgets(2)); // title + button
  });

  testWidgets('small screen with large text stays scrollable without overflow',
      (tester) async {
    await _pump(tester, width: 320, height: 568, textScale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.widgetWithText(AppButton, 'Бүртгүүлэх'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone entry filters pasted text and advances to password',
      (tester) async {
    await _pump(tester);
    final phone = find.descendant(
        of: find.byType(PhoneField), matching: find.byType(TextField));
    await tester.enterText(phone, '8811 2233abc99');
    expect(tester.widget<TextField>(phone).controller!.text, '88112233');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    final password = tester.widget<TextField>(find.descendant(
        of: find.byType(PasswordField), matching: find.byType(TextField)));
    expect(password.focusNode!.hasFocus, isTrue);
  });

  testWidgets('one raised main action; registration is the quiet second',
      (tester) async {
    await _pump(tester);
    expect(find.text('Зочноор үзэх'), findsOneWidget);
    expect(find.text('Шинэ хэрэглэгч үү?'), findsOneWidget);
    final login =
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Нэвтрэх'));
    final register =
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Бүртгүүлэх'));
    expect(login.raised, isTrue);
    expect(login.trailingIcon, AppIcons.next);
    expect(register.variant, AppButtonVariant.secondary);
    expect(register.raised, isFalse);
  });

  testWidgets('a short screen keeps the whole form without overflow',
      (tester) async {
    await _pump(tester, height: 600);

    expect(tester.takeException(), isNull);
    expect(find.byType(PasswordField), findsOneWidget);
  });

  testWidgets('the guest pill is a 44pt target and never cut short',
      (tester) async {
    await _pump(tester);
    final text = tester.widget<Text>(find.text('Зочноор үзэх'));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(
      tester
          .getSize(find.ancestor(
            of: find.text('Зочноор үзэх'),
            matching: find.byType(Pressable),
          ))
          .height,
      greaterThanOrEqualTo(AppLayout.minTapTarget),
    );
  });

  testWidgets('empty fields are refused before any request', (tester) async {
    final api = FakeApi.install((_) => _loginOk);
    await _pump(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Нэвтрэх'));
    await tester.pump();

    expect(find.text(AuthValidators.phoneInvalid), findsOneWidget);
    expect(find.text('Дор хаяж 6 тэмдэгт'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('valid credentials sign in and go home', (tester) async {
    final api = FakeApi.install((_) => _loginOk);
    await _pump(tester);

    await _fillAndSubmit(tester);

    expect(api.callsTo('/auth/login').single.body, {
      'phoneNumber': '88112233',
      'password': 'password1',
    });
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('wrong credentials show the error in the card', (tester) async {
    FakeApi.install((_) => const FakeReply(401));
    await _pump(tester);

    await _fillAndSubmit(tester);

    expect(find.byType(StatusBanner), findsOneWidget);
    expect(find.text(kWrongCredentials), findsOneWidget);
    expect(find.text('home-page'), findsNothing);
  });

  testWidgets('Нууц үг мартсан? opens the reset flow', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Нууц үг мартсан?'));
    await tester.pumpAndSettle();

    expect(find.text('forgot-page'), findsOneWidget);
  });

  testWidgets('Зочноор үзэх goes home without signing in', (tester) async {
    final api = FakeApi.install((_) => _loginOk);
    await _pump(tester);

    await tester.tap(find.text('Зочноор үзэх'));
    await tester.pumpAndSettle();

    expect(find.text('home-page'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('the register link carries the page to return to',
      (tester) async {
    await _pump(tester, next: '/video/5');

    await tester.ensureVisible(find.widgetWithText(AppButton, 'Бүртгүүлэх'));
    await tester.tap(find.widgetWithText(AppButton, 'Бүртгүүлэх'));
    await tester.pumpAndSettle();

    expect(find.text('register-page next=/video/5'), findsOneWidget);
  });

  testWidgets('the phone field keeps a line for its error', (tester) async {
    await _pump(tester);
    // The phone error appears in this reserved line instead of pushing the
    // password field down; the password's own error may move the link.
    expect(tester.widget<PhoneField>(find.byType(PhoneField)).helperText,
        kReservedLine);
  });

  testWidgets('forgot-password sits right-aligned under the password field',
      (tester) async {
    await _pump(tester);
    final link = find.text('Нууц үг мартсан?');
    final field = find.byType(PasswordField);
    expect(tester.getTopLeft(link).dy,
        greaterThan(tester.getBottomLeft(field).dy - 1));
    expect(tester.getCenter(link).dx, greaterThan(tester.getCenter(field).dx));
  });
}
