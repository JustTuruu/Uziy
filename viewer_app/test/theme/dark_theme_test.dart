import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Pumps [builder] under [theme] and returns what it built from the context.
Future<T> _under<T>(
  WidgetTester tester,
  ThemeData theme,
  T Function(BuildContext) builder,
) async {
  late T result;
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Builder(builder: (context) {
      result = builder(context);
      return const SizedBox();
    }),
  ));
  return result;
}

void main() {
  const dark = AppPalette(true);
  const light = AppPalette(false);

  group('AppTheme.dark', () {
    final theme = AppTheme.dark();

    test('is a dark Material 3 theme on the dark palette', () {
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, dark.background);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, dark.primary);
      expect(theme.colorScheme.surface, dark.surface);
    });

    test('light and dark use different backgrounds and text', () {
      final lightTheme = AppTheme.light();
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor,
          isNot(theme.scaffoldBackgroundColor));
      expect(dark.textPrimary, isNot(light.textPrimary));
    });
  });

  group('dark palette: WCAG AA (4.5:1) for text', () {
    final surfaces = {
      'background': dark.background,
      'surface': dark.surface,
      'surfaceElevated': dark.surfaceElevated,
    };
    for (final entry in surfaces.entries) {
      test('text colours on ${entry.key}', () {
        for (final text in [
          dark.textPrimary,
          dark.textSecondary,
          dark.textTertiary,
          dark.primary,
          dark.dangerLight,
          dark.accentLight,
        ]) {
          expect(_contrast(text, entry.value), greaterThanOrEqualTo(4.5),
              reason: '$text on ${entry.key}');
        }
      });
    }

    test('ink on the primary action colour', () {
      for (final fill in [dark.primaryLight, dark.primary, dark.primaryDeep]) {
        expect(_contrast(dark.onPrimary, fill), greaterThanOrEqualTo(4.5));
      }
    });

    test('dark surfaces are actually dark', () {
      for (final c in [dark.background, dark.surface, dark.surfaceElevated]) {
        expect(c.computeLuminance(), lessThan(0.05));
      }
    });
  });

  group('context.colors / textStyles follow the theme', () {
    testWidgets('dark theme gives the dark palette', (tester) async {
      final colors = await _under(tester, AppTheme.dark(), (c) => c.colors);
      expect(colors.isDark, isTrue);
      expect(colors.background, dark.background);
    });

    testWidgets('light theme gives the light palette', (tester) async {
      final colors = await _under(tester, AppTheme.light(), (c) => c.colors);
      expect(colors.isDark, isFalse);
      expect(colors.background, AppColors.background);
    });

    testWidgets('text styles carry the dark text colours', (tester) async {
      final styles = await _under(tester, AppTheme.dark(), (c) => c.textStyles);
      expect(styles.body.color, dark.textPrimary);
      expect(styles.bodySmall.color, dark.textSecondary);
      expect(styles.display.color, dark.textPrimary);
    });
  });

  test('shimmer and icon tiles are visible in both modes', () {
    expect(dark.shimmer, isNot(light.shimmer));
    expect(light.shimmer.a, greaterThan(dark.shimmer.a),
        reason: 'a white sweep needs more strength on a light surface');
    expect(light.iconTile, isNot(Colors.white.withValues(alpha: 0.06)));
  });
}
