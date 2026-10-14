import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/theme/app_theme.dart';
import 'package:viewer_app/theme/theme_controller.dart';
import 'package:viewer_app/widgets/app_button.dart';

class _FormContent extends StatelessWidget {
  const _FormContent();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          const TextField(key: ValueKey('draft')),
          AppButton(label: 'Үргэлжлүүлэх', onPressed: () {}),
        ]),
      );
}

Future<void> _pump(WidgetTester tester, ThemeController controller) =>
    tester.pumpWidget(ListenableBuilder(
      listenable: controller,
      builder: (_, __) => MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: controller.mode,
        home: const _FormContent(),
      ),
    ));

void main() {
  testWidgets(
      'system mode follows device changes and explicit mode overrides it',
      (tester) async {
    final settings = ThemeController(write: (_) async {});
    addTearDown(settings.dispose);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await _pump(tester, settings);
    expect(Theme.of(tester.element(find.byType(AppButton))).brightness,
        Brightness.light);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppButton))).brightness,
        Brightness.dark);
    expect(tester.widget<Text>(find.text('Үргэлжлүүлэх')).style!.color,
        const AppPalette(true).onPrimary);

    await settings.setMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppButton))).brightness,
        Brightness.light);
    await settings.setMode(ThemeMode.system);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppButton))).brightness,
        Brightness.dark);
  });

  testWidgets('switching appearance preserves form text and focus',
      (tester) async {
    final settings = ThemeController(write: (_) async {});
    addTearDown(settings.dispose);
    await _pump(tester, settings);
    await tester.enterText(find.byKey(const ValueKey('draft')), '88112233');
    final before = tester.state<EditableTextState>(find.byType(EditableText));
    expect(before.widget.focusNode.hasFocus, isTrue);

    await settings.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    final after = tester.state<EditableTextState>(find.byType(EditableText));
    expect(identical(before, after), isTrue);
    expect(after.widget.controller.text, '88112233');
    expect(after.widget.focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('all dark semantic foregrounds contrast with their backgrounds', () {
    final scheme = AppTheme.dark().colorScheme;
    for (final pair in [
      (scheme.primary, scheme.onPrimary),
      (scheme.secondary, scheme.onSecondary),
      (scheme.tertiary, scheme.onTertiary),
      (scheme.error, scheme.onError),
      (scheme.errorContainer, scheme.onErrorContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    ]) {
      final a = pair.$1.computeLuminance();
      final b = pair.$2.computeLuminance();
      final ratio = ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });
}
