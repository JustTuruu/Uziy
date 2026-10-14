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
    final cards = tester.widgetList<ThemeModeCard>(find.byType(ThemeModeCard));
    expect(cards.map((c) => c.mode), ThemeModeChoices.order);
    expect(
        cards.where((c) => c.selected).map((c) => c.mode), [ThemeMode.system]);
    expect(find.byType(ThemePreview), findsNWidgets(3));
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
    expect(tester.takeException(), isNull);
    // Too narrow for three cards side by side: they stack.
    final light = tester.getTopLeft(find.byType(ThemeModeCard).at(0));
    final dark = tester.getTopLeft(find.byType(ThemeModeCard).at(1));
    expect(dark.dy, greaterThan(light.dy));
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

  testWidgets('on a normal phone the three cards sit side by side',
      (tester) async {
    final c = _controller();
    await _pump(tester, c);
    await tester.tap(find.text('Харагдах горим'));
    await tester.pumpAndSettle();
    final tops = [
      for (var i = 0; i < 3; i++)
        tester.getTopLeft(find.byType(ThemeModeCard).at(i)).dy,
    ];
    expect(tops.toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a preview card picks that mode', (tester) async {
    final c = _controller();
    await _pump(tester, c);
    await tester.tap(find.text('Харагдах горим'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ThemePreview).at(1));
    await tester.pumpAndSettle();
    expect(c.mode, ThemeMode.dark);
  });

  group('ThemeModeButton', () {
    Future<void> pumpButton(WidgetTester tester, ThemeController c,
        {Brightness platform = Brightness.light}) {
      tester.platformDispatcher.platformBrightnessTestValue = platform;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      return tester.pumpWidget(ListenableBuilder(
        listenable: c,
        builder: (_, __) => MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: c.mode,
          home: Scaffold(body: Center(child: ThemeModeButton(controller: c))),
        ),
      ));
    }

    test('icon and label follow the look on screen', () {
      expect(ThemeModeButton.iconFor(Brightness.light),
          isNot(ThemeModeButton.iconFor(Brightness.dark)));
      expect(ThemeModeButton.labelFor(Brightness.light),
          ThemeModeButton.toDarkLabel);
      expect(ThemeModeButton.labelFor(Brightness.dark),
          ThemeModeButton.toLightLabel);
    });

    testWidgets('a tap switches light -> dark -> light at once',
        (tester) async {
      final saved = <String>[];
      final c = _controller(saved: saved);
      await pumpButton(tester, c);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

      await tester.tap(find.byType(ThemeModeButton));
      await tester.pumpAndSettle();
      expect(c.mode, ThemeMode.dark);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_rounded), findsNothing);

      await tester.tap(find.byType(ThemeModeButton));
      await tester.pumpAndSettle();
      expect(c.mode, ThemeMode.light);
      expect(saved, ['dark', 'light']);
      expect(find.byType(AppearanceSheet), findsNothing);
    });

    testWidgets('following a dark device, a tap goes to light', (tester) async {
      final c = _controller();
      await pumpButton(tester, c, platform: Brightness.dark);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      await tester.tap(find.byType(ThemeModeButton));
      await tester.pumpAndSettle();
      expect(c.mode, ThemeMode.light);
    });

    testWidgets('a failed save keeps the new look and says so', (tester) async {
      final c = _controller(failWrites: true);
      await pumpButton(tester, c);
      await tester.tap(find.byType(ThemeModeButton));
      await tester.pumpAndSettle();
      expect(c.mode, ThemeMode.dark);
      expect(find.text(AppearanceSheet.saveFailedMessage), findsOneWidget);
    });

    testWidgets('a long press opens the full appearance sheet', (tester) async {
      final c = _controller();
      await pumpButton(tester, c);
      await tester.longPress(find.byType(ThemeModeButton));
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceSheet), findsOneWidget);
      expect(c.mode, ThemeMode.system);
    });
  });
}
