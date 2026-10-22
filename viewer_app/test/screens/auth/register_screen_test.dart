import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/routes/app_router.dart' show Routes;
import 'package:viewer_app/screens/auth/auth_widgets.dart';
import 'package:viewer_app/screens/auth/birth_date_picker.dart';
import 'package:viewer_app/screens/auth/register_screen.dart';
import 'package:viewer_app/models/regions.dart';
import 'package:viewer_app/screens/auth/location_fields.dart';
import 'package:viewer_app/widgets/incentive_banner.dart';
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

/// Ticks the terms box and submits.
Future<void> _agreeAndSubmit(WidgetTester tester) async {
  final tile = find.byType(TermsAgreementTile);
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  // The box sits at the tile's top-left; the links are in the text.
  await tester.tapAt(tester.getTopLeft(tile) + const Offset(30, 30));
  await tester.pumpAndSettle();
  final submit = find.widgetWithText(AppButton, kContinueLabel);
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  /// The owner's request (2026-10-14): овог and нэр are asked separately.
  // Owner, 2026-10-22: the month calendar was hard to use; the birth date is
  // picked on Он · Сар · Өдөр wheels.
  testWidgets('the birth date opens the wheels and fills the field',
      (tester) async {
    await _pump(tester);
    await tester.ensureVisible(find.byType(BirthDateTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BirthDateTile));
    await tester.pumpAndSettle();

    expect(find.byType(BirthDateSheet), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);

    await tester.tap(find.text(kBirthPickerDone));
    await tester.pumpAndSettle();

    expect(find.byType(BirthDateSheet), findsNothing);
    final tile = tester.widget<BirthDateTile>(find.byType(BirthDateTile));
    expect(tile.value, isNotNull);
    expect(find.text(formatBirthDate(tile.value!)), findsOneWidget);
  });

  testWidgets('asks for овог and нэр as two separate fields', (tester) async {
    await _pump(tester);

    expect(find.text('Овог'), findsOneWidget);
    expect(find.text('Нэр'), findsOneWidget);
  });

  /// Owner (2026-10-14): the "true details earn more" note is back, above
  /// the first field.
  testWidgets('shows the incentive note above the phone field', (tester) async {
    await _pump(tester);
    expect(find.byType(IncentiveBanner), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(IncentiveBanner)).dy,
      lessThan(tester.getTopLeft(find.text('Утасны дугаар')).dy),
    );
  });

  testWidgets('registration keeps labels and removes text field placeholders',
      (tester) async {
    await _pump(tester);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.decoration?.hintText, anyOf(isNull, isEmpty));
    }
    expect(find.text('Утасны дугаар'), findsOneWidget);
    expect(find.text('Нууц үг'), findsOneWidget);
    expect(find.byType(TermsAgreementTile), findsOneWidget);
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

    final lastName = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        (widget.autofillHints?.contains(AutofillHints.familyName) ?? false));
    await tester.enterText(lastName, 'Бат1');
    await _agreeAndSubmit(tester);

    expect(find.text(AuthValidators.nameLetters), findsOneWidget);
  });

  testWidgets(
      'submitting before agreeing marks the terms instead of a dead button',
      (tester) async {
    await _pump(tester);

    final submit = find.widgetWithText(AppButton, kContinueLabel);
    expect(tester.widget<AppButton>(submit).onPressed, isNotNull,
        reason: 'a disabled button would not say what is missing');
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text(kTermsRequired), findsOneWidget);
    expect(
        tester
            .widget<TermsAgreementTile>(find.byType(TermsAgreementTile))
            .error,
        isTrue);

    await tester.tapAt(tester.getTopLeft(find.byType(TermsAgreementTile)) +
        const Offset(30, 30));
    await tester.pumpAndSettle();
    expect(find.text(kTermsRequired), findsNothing);
  });

  /// Owner, 2026-10-22: the 'Дараа нь дугаараа SMS-ээр баталгаажуулна…'
  /// caption above the button was removed; the verify page tells the price.
  /// The button still does not claim to finish the registration.
  testWidgets('the pinned bar is just the continue button', (tester) async {
    await _pump(tester);
    expect(find.textContaining('SMS'), findsNothing);
    expect(find.textContaining('150₮'), findsNothing);
    expect(find.widgetWithText(AppButton, kContinueLabel), findsOneWidget);
  });

  // Owner, 2026-10-21: the page promises no reward amount ('Нэг
  // судалгаанаас 500–700 ₮' was removed); the spec note follows the title.
  testWidgets('states no reward amount; the spec note comes right after',
      (tester) async {
    await _pump(tester);
    expect(find.textContaining('Нэг судалгаанаас'), findsNothing);
    expect(find.textContaining('500'), findsNothing);
    expect(find.textContaining('700'), findsNothing);
    expect(find.byType(CoinIcon), findsNothing);
    expect(
      tester.getTopLeft(find.byType(AuthPageTitle)).dy,
      lessThan(tester.getTopLeft(find.byType(IncentiveBanner)).dy),
    );
  });

  testWidgets('no city is preselected; submitting asks for one',
      (tester) async {
    await _pump(tester);
    expect(find.text(kDistrictLabel), findsNothing,
        reason: 'the district appears only once Улаанбаатар is picked');
    await _agreeAndSubmit(tester);
    expect(find.text(kCityRequired), findsOneWidget);
  });

  testWidgets('screen readers hear each field by its label', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    final labels = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((e) => tester.getSemantics(find.byWidget(e)).label)
        .toList();
    expect(labels, containsAll(['Утасны дугаар', 'Нууц үг', 'Овог', 'Нэр']));
    semantics.dispose();
  });
}
