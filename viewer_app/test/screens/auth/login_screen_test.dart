import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
  String? next,
}) async {
  tester.view.physicalSize = Size(390, height) * 3;
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
      theme: AppTheme.dark(),
      routerConfig: router,
      // The falling coins loop forever; frozen coins let pumpAndSettle end.
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: app!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillAndSubmit(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
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

  testWidgets('shows the welcome, both fields and the card around them',
      (tester) async {
    await _pump(tester);

    expect(find.text('Тавтай морил'), findsOneWidget);
    expect(find.text('Нэвтрэх'), findsNWidgets(2)); // title + button
    expect(find.byType(PhonePrefixField), findsOneWidget);
    expect(find.byType(PasswordField), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(PasswordField),
        matching: find.byType(AppCard),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a tall screen shows the three-step strip', (tester) async {
    await _pump(tester);

    expect(find.byType(HowItWorksStrip), findsOneWidget);
    for (final step in HowItWorksStrip.steps) {
      expect(find.text(step.label), findsOneWidget);
    }
  });

  testWidgets('a short screen drops the strip so the form stays in view',
      (tester) async {
    await _pump(tester, height: 600);

    expect(find.byType(HowItWorksStrip), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.byType(PasswordField), findsOneWidget);
  });

  testWidgets('empty fields are refused before any request', (tester) async {
    final api = FakeApi.install((_) => _loginOk);
    await _pump(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Нэвтрэх'));
    await tester.pump();

    expect(find.text('Утасны дугаараа шалгана уу'), findsOneWidget);
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
    expect(find.text('Утас эсвэл нууц үг буруу байна'), findsOneWidget);
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

    await tester.ensureVisible(find.byType(AuthFooterLink));
    await tester.tap(find.byType(AuthFooterLink));
    await tester.pumpAndSettle();

    expect(find.text('register-page next=/video/5'), findsOneWidget);
  });

  group('authHeroMetrics', () {
    test('a tall screen gets the big logo and room for extras', () {
      final m = authHeroMetrics(844);
      expect(m.logoSize, 76);
      expect(m.compact, isFalse);
    });

    test('a short screen gets the small logo and drops extras', () {
      final m = authHeroMetrics(kCompactAuthHeight - 1);
      expect(m.logoSize, 56);
      expect(m.compact, isTrue);
    });

    test('exactly at the threshold counts as tall', () {
      expect(authHeroMetrics(kCompactAuthHeight).compact, isFalse);
    });
  });
}
