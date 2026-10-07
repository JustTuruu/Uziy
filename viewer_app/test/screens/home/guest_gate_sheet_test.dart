import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/home/guest_gate_sheet.dart';
import 'package:viewer_app/widgets/ui.dart';

Future<void> _open(WidgetTester tester, List<GuestChoice?> results) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                results.add(await showGuestGateSheet(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the explanation and both choices', (tester) async {
    await _open(tester, []);

    expect(find.text(kGuestGateTitle), findsOneWidget);
    expect(find.text(kGuestGateMessage), findsOneWidget);
    expect(find.text(kGuestRegisterLabel), findsOneWidget);
    expect(find.text(kGuestLoginLabel), findsOneWidget);
  });

  testWidgets('Бүртгүүлэх resolves to register', (tester) async {
    final results = <GuestChoice?>[];
    await _open(tester, results);

    await tester.tap(find.text(kGuestRegisterLabel));
    await tester.pumpAndSettle();

    expect(results, [GuestChoice.register]);
    expect(find.text(kGuestGateTitle), findsNothing);
  });

  testWidgets('Нэвтрэх resolves to login', (tester) async {
    final results = <GuestChoice?>[];
    await _open(tester, results);

    await tester.tap(find.text(kGuestLoginLabel));
    await tester.pumpAndSettle();

    expect(results, [GuestChoice.login]);
  });

  testWidgets('dismissing the sheet resolves to null', (tester) async {
    final results = <GuestChoice?>[];
    await _open(tester, results);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });
}
