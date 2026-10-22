import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:viewer_app/routes/app_router.dart';
import 'package:viewer_app/screens/auth/auth_widgets.dart';
import 'package:viewer_app/screens/profile/profile_screen.dart';
import 'package:viewer_app/screens/profile/profile_widgets.dart';
import 'package:viewer_app/screens/wallet/add_name_sheet.dart';
import 'package:viewer_app/screens/wallet/wallet_widgets.dart';
import 'package:viewer_app/widgets/app_nav_bar.dart';
import 'package:viewer_app/widgets/appearance_settings.dart';
import 'package:viewer_app/widgets/ui.dart';

import '../support/fake_api.dart';

/// Regression (owner's screenshot, 2026-10-22): a sheet opened from a tab was
/// pushed on the ShellRoute's nested navigator, so the floating tab bar was
/// painted over it — it hid the add-name sheet's button and the scrim stopped
/// at the bar. Sheets now open on the root navigator (showAppSheet).

const _tabLabels = ['Нүүр', 'Хэтэвч', 'Профайл'];

/// A viewer made before registration asked for a name.
void _backend() => FakeApi.install((call) => switch (call.path) {
      '/viewer/me' => const FakeReply(200, {
          'id': 100,
          'phoneNumber': '88112233',
          'role': 'VIEWER',
          'balance': 1200,
          'isVerified': false,
        }),
      '/viewer/payouts' => const FakeReply(200, []),
      '/viewer/history' => const FakeReply(200, []),
      _ => const FakeReply(404),
    });

/// The real shell (router with the bottom nav) opened on [location].
Future<void> _pumpShell(
  WidgetTester tester,
  String location, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
  double homeIndicator = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(bottom: homeIndicator);
  tester.view.viewPadding = FakeViewPadding(bottom: homeIndicator);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: location,
    routes: appRouter.configuration.routes,
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(
    theme: AppTheme.dark(),
    routerConfig: router,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: app!,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Lets the sheet's entrance animation finish.
Future<void> _settleSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Unmounts the shell so the tabs' load/refresh timers end with the test.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

/// The sheet holding [inSheet] lives on the root navigator and covers the
/// tab bar: no tab label can be tapped while it is open.
void _expectOverTabBar(WidgetTester tester, Finder inSheet) {
  final element = tester.element(inSheet);
  expect(
    Navigator.of(element),
    same(Navigator.of(element, rootNavigator: true)),
    reason: 'the sheet route must be on the root navigator',
  );
  for (final label in _tabLabels) {
    final tab = find.descendant(
      of: find.byType(AppNavBar),
      matching: find.text(label),
    );
    expect(tab, findsOneWidget, reason: '$label is in the bar');
    expect(tab.hitTestable(), findsNothing,
        reason: 'the scrim covers the tab bar ($label)');
  }
}

Future<void> _openAddNameSheet(WidgetTester tester) async {
  expect(find.byType(AddNameChip), findsOneWidget);
  await tester.tap(find.byType(AddNameChip));
  await _settleSheet(tester);
  expect(find.byType(AddNameSheet), findsOneWidget);
}

void main() {
  testWidgets(
      'the add-name sheet opened from the wallet tab is above the tab bar '
      '(regression)', (tester) async {
    _backend();
    await _pumpShell(tester, Routes.wallet, homeIndicator: 34);
    await _openAddNameSheet(tester);

    expect(find.text(kAddNameSave).hitTestable(), findsOneWidget,
        reason: 'the save button is not covered by the tab bar');
    expect(find.text(PersonNameFields.firstNameLabel).hitTestable(),
        findsOneWidget);
    _expectOverTabBar(tester, find.byType(AddNameSheet));
    expect(tester.getRect(find.text(kAddNameSave)).bottom,
        lessThanOrEqualTo(844 - 34),
        reason: 'the button stays above the home indicator');
    await _close(tester);
  });

  testWidgets(
      'on a small phone with large text the add-name sheet scrolls to its '
      'button and keeps it above the keyboard', (tester) async {
    _backend();
    await _pumpShell(
      tester,
      Routes.wallet,
      size: const Size(320, 568),
      textScale: 1.3,
      homeIndicator: 34,
    );
    await _openAddNameSheet(tester);

    const keyboard = 260.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pump();

    await tester.dragUntilVisible(
      find.text(kAddNameSave),
      find.descendant(
        of: find.byType(AddNameSheet),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -60),
    );
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'no overflow');
    expect(find.text(kAddNameSave).hitTestable(), findsOneWidget);
    expect(tester.getRect(find.text(kAddNameSave)).bottom,
        lessThanOrEqualTo(568 - keyboard),
        reason: 'the button stays above the keyboard');
    _expectOverTabBar(tester, find.byType(AddNameSheet));
    await _close(tester);
  });

  testWidgets(
      'the logout sheet opened from the profile tab is above the tab '
      'bar (regression)', (tester) async {
    _backend();
    await _pumpShell(tester, Routes.profile, homeIndicator: 34);

    showLogoutConfirmSheet(tester.element(find.byType(ProfileScreen)));
    await _settleSheet(tester);

    final logout = find.descendant(
      of: find.byType(LogoutConfirmSheet),
      matching: find.text('Гарах'),
    );
    expect(logout.hitTestable(), findsOneWidget);
    expect(find.text('Болих').hitTestable(), findsOneWidget);
    _expectOverTabBar(tester, find.byType(LogoutConfirmSheet));
    await _close(tester);
  });

  testWidgets(
      'the appearance sheet opened from the profile tab is above the '
      'tab bar (regression)', (tester) async {
    _backend();
    await _pumpShell(tester, Routes.profile, homeIndicator: 34);

    showAppearanceSettings(tester.element(find.byType(ProfileScreen)));
    await _settleSheet(tester);

    expect(find.byType(AppearanceSheet), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Боллоо'),
      find.descendant(
        of: find.byType(AppearanceSheet),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -60),
    );
    await tester.pump();
    expect(find.text('Боллоо').hitTestable(), findsOneWidget);
    _expectOverTabBar(tester, find.byType(AppearanceSheet));
    await _close(tester);
  });
}
