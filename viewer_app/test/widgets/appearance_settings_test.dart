import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/theme/app_theme.dart';
import 'package:viewer_app/theme/theme_controller.dart';
import 'package:viewer_app/widgets/appearance_settings.dart';

ThemeController _controller({bool failWrites = false, List<String>? saved}) =>
    ThemeController(
      read: () async => null,
      write: (v) async {
        if (failWrites) throw Exception('storage unavailable');
        saved?.add(v);
      },
    );

/// Wired like app.dart: the MaterialApp's themeMode follows the controller.
Future<void> _pump(WidgetTester tester, ThemeController c) async {
  await tester.pumpWidget(ListenableBuilder(
    listenable: c,
    builder: (_, __) => MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: c.mode,
      home: Scaffold(body: AppearanceSettings(controller: c)),
    ),
  ));
}

void main() {
  testWidgets('the row names the current mode', (tester) async {
    final c = _controller();
    await _pump(tester, c);

    expect(find.text('Харагдах горим'), findsOneWidget);
    expect(find.text('Төхөөрөмжийн тохиргоо'), findsOneWidget);
  });

  testWidgets('tapping opens a sheet with the three modes, current one ticked',
      (tester) async {
    final c = _controller();
    await _pump(tester, c);

    await tester.tap(find.text('Харагдах горим'));
    await tester.pumpAndSettle();

    for (final mode in ThemeMode.values) {
      expect(find.text(ThemeController.label(mode)), findsWidgets);
    }
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('choosing Бараан switches to dark and saves it', (tester) async {
    final saved = <String>[];
    final c = _controller(saved: saved);
    await _pump(tester, c);

    await tester.tap(find.text('Харагдах горим'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Бараан'));
    await tester.pumpAndSettle();

    expect(c.mode, ThemeMode.dark);
    expect(saved, ['dark']);
    final context = tester.element(find.byType(AppearanceSheet));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('a failed save says so but keeps the new look', (tester) async {
    final c = _controller(failWrites: true);
    await _pump(tester, c);

    await tester.tap(find.text('Харагдах горим'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Цайвар'));
    await tester.pumpAndSettle();

    expect(c.mode, ThemeMode.light);
    expect(
      find.text(
          'Горим солигдлоо. Тохиргоог хадгалж чадсангүй, дахин сонгоно уу.'),
      findsOneWidget,
    );
  });
  testWidgets('small phone with large text can see a save error and dismiss',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = _controller(failWrites: true);
    addTearDown(c.dispose);
    await _pump(tester, c);
    await tester.tap(find.text('Харагдах горим'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Бараан'));
    await tester.tap(find.text('Бараан'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(AppearanceSheet),
            matching: find.text(
                'Горим солигдлоо. Тохиргоог хадгалж чадсангүй, дахин сонгоно уу.')),
        findsOneWidget);
    await tester.ensureVisible(find.text('Боллоо'));
    await tester.tap(find.text('Боллоо'));
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceSheet), findsNothing);
    expect(c.mode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });
}
