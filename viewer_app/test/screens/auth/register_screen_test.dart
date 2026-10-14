import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/screens/auth/auth_widgets.dart';
import 'package:viewer_app/screens/auth/register_screen.dart';
import 'package:viewer_app/widgets/ui.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 2600) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.register,
    routes: [
      GoRoute(
          path: Routes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const Text('login')),
      GoRoute(path: Routes.home, builder: (_, __) => const Text('home')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: router,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: app!,
    ),
  ));
  await tester.pumpAndSettle();
}

/// Ticks the terms box (the button stays disabled until then) and submits.
Future<void> _agreeAndSubmit(WidgetTester tester) async {
  final tile = find.byType(TermsAgreementTile);
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  // The box sits at the tile's top-left; the links are in the text.
  await tester.tapAt(tester.getTopLeft(tile) + const Offset(30, 30));
  await tester.pumpAndSettle();
  final submit = find.widgetWithText(AppButton, 'Бүртгүүлэх');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  /// The owner's request (2026-10-14): овог and нэр are asked separately.
  testWidgets('asks for овог and нэр as two separate fields', (tester) async {
    await _pump(tester);

    expect(find.text('Овог'), findsOneWidget);
    expect(find.text('Нэр'), findsOneWidget);
  });

  testWidgets('submitting without them names each missing field',
      (tester) async {
    await _pump(tester);

    await _agreeAndSubmit(tester);

    expect(find.text(AuthValidators.lastNameRequired), findsOneWidget);
    expect(find.text(AuthValidators.firstNameRequired), findsOneWidget);
  });

  testWidgets('a name with digits is refused under its field', (tester) async {
    await _pump(tester);

    final lastName = find.ancestor(
      of: find.text('Жишээ нь: Оюун-Эрдэнэ'),
      matching: find.byType(TextField),
    );
    await tester.enterText(lastName, 'Бат1');
    await _agreeAndSubmit(tester);

    expect(find.text(AuthValidators.nameLetters), findsOneWidget);
  });
}
