import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/wallet/add_name_sheet.dart';
import 'package:viewer_app/screens/wallet/wallet_logic.dart';
import 'package:viewer_app/screens/wallet/wallet_screen.dart';
import 'package:viewer_app/screens/wallet/wallet_widgets.dart';
import 'package:viewer_app/services/auto_refresher.dart';
import 'package:viewer_app/widgets/ui.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _me({required double balance, required bool verified}) => {
      'id': 100,
      'phoneNumber': '88112233',
      'role': 'VIEWER',
      'balance': balance,
      'isVerified': verified,
    };

Map<String, Object?> _payout(String status) => {
      'id': 7,
      'amount': 5000,
      'bank': 'Khan Bank',
      'status': status,
      'requestedAt': '2026-10-14T03:00:00Z',
      'decidedAt': status == 'PENDING' ? null : '2026-10-14T04:00:00Z',
      'rejectReason': null,
    };

/// A backend where the admin's decision can be flipped mid-test.
class _Backend {
  String status = 'PENDING';
  late final FakeApi api = FakeApi.install((call) => switch (call.path) {
        '/viewer/me' => FakeReply(
            200,
            _me(balance: 1200, verified: status == 'APPROVED'),
          ),
        '/viewer/payouts' => FakeReply(200, [_payout(status)]),
        '/viewer/history' => const FakeReply(200, [
            {
              'campaignId': 1,
              'title': 'Шинэ 5G багц',
              'companyName': 'MobiCom',
              'rewardPaid': 700,
              'watchedAt': '2026-10-13T03:00:00Z',
            },
          ]),
        _ => const FakeReply(404),
      });

  int get loads => api.callsTo('/viewer/me').length;
}

Future<void> _pumpWallet(WidgetTester tester) async {
  // Tall enough that the history below the card is built.
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: const Scaffold(body: WalletScreen()),
  ));
  await tester.pumpAndSettle();
}

/// Disposing the screen cancels its refresh timer before the test ends.
Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  const tick = AutoRefresher.defaultInterval;

  testWidgets(
      'an admin approval shows up by itself, without pull-to-refresh '
      '(regression)', (tester) async {
    final backend = _Backend()..api;
    await _pumpWallet(tester);

    expect(find.text(kWalletHistoryTitle), findsOneWidget);
    expect(find.textContaining('Хянагдаж байна'), findsOneWidget);
    expect(find.text('Шинэ 5G багц'), findsOneWidget);
    expect(find.text(WalletVerifiedBadge.unverifiedLabel), findsOneWidget);

    backend.status = 'APPROVED';
    await tester.pump(tick);
    await tester.pumpAndSettle();

    expect(find.textContaining('Дансанд шилжүүлсэн'), findsOneWidget);
    expect(find.textContaining('Хянагдаж байна'), findsNothing);
    expect(find.text(WalletVerifiedBadge.verifiedLabel), findsOneWidget);
    expect(find.text('5,000 ₮ татах хүсэлт тань батлагдлаа'), findsOneWidget,
        reason: 'the decision is announced in a snack bar');

    // Nothing waits any more: no further polling.
    final loads = backend.loads;
    await tester.pump(tick * 3);
    expect(backend.loads, loads);
    await _close(tester);
  });

  testWidgets('a rejection says the money came back', (tester) async {
    final backend = _Backend()..api;
    await _pumpWallet(tester);

    backend.status = 'REJECTED';
    await tester.pump(tick);
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Татгалзсан · хэтэвчинд буцсан'), findsOneWidget);
    expect(find.textContaining('хэтэвчинд буцлаа'), findsWidgets);
    await _close(tester);
  });

  group('first-payout note under the button', () {
    const note = 'Эхний удаа мөнгө татахад';

    void backendWith(List<Map<String, Object?>> payouts) =>
        FakeApi.install((call) => switch (call.path) {
              '/viewer/me' =>
                FakeReply(200, _me(balance: 5000, verified: false)),
              '/viewer/payouts' => FakeReply(200, payouts),
              '/viewer/history' => const FakeReply(200, []),
              _ => const FakeReply(404),
            });

    testWidgets('shown before the first payout', (tester) async {
      backendWith(const []);
      await _pumpWallet(tester);
      expect(find.textContaining(note), findsOneWidget);
      await _close(tester);
    });

    /// Regression (2026-10-14): it stayed after the first request was made.
    testWidgets('gone once the first request is waiting', (tester) async {
      backendWith([_payout('PENDING')]);
      await _pumpWallet(tester);
      expect(find.textContaining(note), findsNothing);
      await _close(tester);
    });
  });

  testWidgets('the card shows the registered name', (tester) async {
    FakeApi.install((call) => switch (call.path) {
          '/viewer/me' => FakeReply(200, {
              ..._me(balance: 5000, verified: true),
              'lastName': 'Оюун-Эрдэнэ',
              'firstName': 'Төрболд',
            }),
          '/viewer/payouts' => FakeReply(200, [
              {..._payout('APPROVED'), 'accountName': 'GGGG'},
            ]),
          '/viewer/history' => const FakeReply(200, []),
          _ => const FakeReply(404),
        });
    await _pumpWallet(tester);

    expect(find.text('ТӨРБОЛД ОЮУН-ЭРДЭНЭ'), findsOneWidget);
    expect(find.text('GGGG'), findsNothing);
    await _close(tester);
  });

  // Owner, 2026-10-21: the card prints only the registered name — never the
  // account holder typed on a payout, which can be someone else's.
  testWidgets('without a registered name the card shows no payout name',
      (tester) async {
    FakeApi.install((call) => switch (call.path) {
          '/viewer/me' => FakeReply(200, _me(balance: 5000, verified: true)),
          '/viewer/payouts' => FakeReply(200, [
              {..._payout('APPROVED'), 'accountName': 'Болд Эрдэнэ'},
            ]),
          '/viewer/history' => const FakeReply(200, []),
          _ => const FakeReply(404),
        });
    await _pumpWallet(tester);

    expect(find.text('БОЛД ЭРДЭНЭ'), findsNothing);
    expect(find.byType(WalletBalanceCard), findsOneWidget);
    await _close(tester);
  });

  testWidgets('with nothing pending it does not poll', (tester) async {
    final backend = _Backend()..status = 'APPROVED';
    backend.api;
    await _pumpWallet(tester);
    expect(backend.loads, 1);
    await tester.pump(tick * 3);
    expect(backend.loads, 1);
    await _close(tester);
  });

  testWidgets('coming back to the app reloads at once', (tester) async {
    final backend = _Backend()..status = 'APPROVED';
    backend.api;
    await _pumpWallet(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(backend.loads, 2);
    await _close(tester);
  });

  testWidgets(
      'an account without a name adds it from the card and the card shows it',
      (tester) async {
    var named = false;
    final api = FakeApi.install((call) => switch (call.path) {
          '/viewer/me' => FakeReply(200, {
              ..._me(balance: 900, verified: false),
              if (named) 'lastName': 'Бат',
              if (named) 'firstName': 'Сараа',
            }),
          '/viewer/me/name' => () {
              named = true;
              return FakeReply(200, {
                ..._me(balance: 900, verified: false),
                'lastName': 'Бат',
                'firstName': 'Сараа',
              });
            }(),
          '/viewer/payouts' => const FakeReply(200, []),
          '/viewer/history' => const FakeReply(200, []),
          _ => const FakeReply(404),
        });
    await _pumpWallet(tester);

    expect(find.byType(AddNameChip), findsOneWidget);
    await tester.tap(find.byType(AddNameChip));
    await tester.pumpAndSettle();

    final fields = find.descendant(
        of: find.byType(AddNameSheet), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), 'Бат');
    await tester.enterText(fields.at(1), 'Сараа');
    await tester.tap(find.text(kAddNameSave));
    await tester.pumpAndSettle();

    expect(api.callsTo('/viewer/me/name').single.body,
        {'lastName': 'Бат', 'firstName': 'Сараа'});
    expect(find.text('САРАА БАТ'), findsOneWidget);
    expect(find.byType(AddNameChip), findsNothing);
    expect(find.text(kAddNameSaved), findsOneWidget);
    await _close(tester);
  });

  // Owner, 2026-10-21: a forest button under the forest card melted into it.
  testWidgets('the payout button is tonal, not the card\'s solid green',
      (tester) async {
    FakeApi.install((call) => switch (call.path) {
          '/viewer/me' => FakeReply(200, _me(balance: 5000, verified: true)),
          '/viewer/payouts' => const FakeReply(200, []),
          '/viewer/history' => const FakeReply(200, []),
          _ => const FakeReply(404),
        });
    await _pumpWallet(tester);
    final button =
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Мөнгө татах'));
    expect(button.variant, AppButtonVariant.tonal);
    await _close(tester);
  });
}
