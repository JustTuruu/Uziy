import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/user.dart';
import 'package:viewer_app/screens/profile/delete_account_sheet.dart';
import 'package:viewer_app/screens/profile/privacy_content.dart';
import 'package:viewer_app/screens/profile/profile_logic.dart';
import 'package:viewer_app/screens/profile/profile_widgets.dart';
import 'package:viewer_app/services/viewer_service.dart';
import 'package:viewer_app/widgets/ui.dart';

Future<void> _pump(
  WidgetTester tester, {
  num balance = 0,
  required DeleteAccount onDelete,
  void Function(bool)? onClosed,
}) async {
  tester.view.physicalSize = const Size(390, 1400) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final r = await showDeleteAccountSheet(context,
                balance: balance, onDelete: onDelete);
            onClosed?.call(r);
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester, String password) async {
  await tester.enterText(find.byType(TextField), password);
  await tester.ensureVisible(find.text(kDeleteConfirm));
  await tester.tap(find.text(kDeleteConfirm));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('says what is deleted, in the privacy page wording',
      (tester) async {
    await _pump(tester, onDelete: (_) async {});

    expect(find.text(kDeleteTitle), findsOneWidget);
    for (final fact in kDeleteAccountFacts) {
      expect(find.text(fact), findsOneWidget);
    }
  });

  testWidgets('warns that the balance is forfeited only when there is one',
      (tester) async {
    await _pump(tester, balance: 3400, onDelete: (_) async {});
    expect(find.text(deleteBalanceWarning(3400)), findsOneWidget);
    expect(deleteBalanceWarning(3400), contains('3,400'));
  });

  testWidgets('no balance warning with an empty wallet', (tester) async {
    await _pump(tester, onDelete: (_) async {});
    expect(find.byKey(const ValueKey('delete-balance-warning')), findsNothing);
  });

  testWidgets('an empty password never reaches the server', (tester) async {
    var calls = 0;
    await _pump(tester, onDelete: (_) async => calls++);

    await _confirm(tester, '');

    expect(calls, 0);
    expect(find.text(kDeletePasswordRequired), findsOneWidget);
  });

  testWidgets('the typed password is sent and the sheet closes with true',
      (tester) async {
    final sent = <String>[];
    bool? closed;
    await _pump(tester,
        onDelete: (p) async => sent.add(p), onClosed: (r) => closed = r);

    await _confirm(tester, 'secret12');

    expect(sent, ['secret12']);
    expect(closed, isTrue);
    expect(find.text(kDeleteTitle), findsNothing);
  });

  testWidgets('a refusal is shown in the sheet, which stays open',
      (tester) async {
    const wrong = 'Нууц үг буруу байна. Дахин оролдоно уу';
    await _pump(tester, onDelete: (_) async {
      throw ApiException(400, wrong);
    });

    await _confirm(tester, 'nope');

    expect(find.text(wrong), findsOneWidget);
    expect(find.text(kDeleteTitle), findsOneWidget);
  });

  testWidgets('Болих closes without deleting', (tester) async {
    var calls = 0;
    bool? closed;
    await _pump(tester,
        onDelete: (_) async => calls++, onClosed: (r) => closed = r);

    await tester.ensureVisible(find.text(kDeleteCancel));
    await tester.tap(find.text(kDeleteCancel));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(closed, isFalse);
  });

  testWidgets('fits a small phone with 1.3x text and a balance',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: app!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDeleteAccountSheet(context,
                balance: 123456, onDelete: (_) async {}),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(kDeleteTitle), findsOneWidget);
  });

  group('profile row', () {
    const user = AppUser(
      id: 7,
      phoneNumber: '88778899',
      role: UserRole.viewer,
      balance: 0,
      isVerified: false,
    );

    Future<void> pumpBody(WidgetTester tester, {VoidCallback? onDelete}) {
      tester.view.physicalSize = const Size(390, 2400) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileBody(
              user: user,
              onLogout: () {},
              onDeleteAccount: onDelete,
            ),
          ),
        ),
      ));
    }

    testWidgets('sits under Гарах and opens the deletion', (tester) async {
      var taps = 0;
      await pumpBody(tester, onDelete: () => taps++);
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('profile-delete-account'));
      expect(find.text(kDeleteAccountLabel), findsOneWidget);
      expect(tester.getTopLeft(row).dy,
          greaterThan(tester.getTopLeft(find.text('Гарах')).dy));
      await tester.tap(row);
      expect(taps, 1);
    });

    testWidgets('is hidden until the profile is known', (tester) async {
      await pumpBody(tester);
      await tester.pumpAndSettle();
      expect(find.text(kDeleteAccountLabel), findsNothing);
    });
  });

  test('the privacy page explains deletion with the same facts', () {
    final section =
        kPrivacySections.singleWhere((s) => s.heading == kDeleteSectionHeading);
    for (final fact in [
      kDeleteFactPersonal,
      kDeleteFactAnswers,
      kDeleteFactPayouts,
      kDeleteFactBalance,
      kDeleteFactPending,
    ]) {
      expect(section.body, contains(fact));
    }
    expect(section.body, contains(kDeleteAccountLabel));
  });
}
