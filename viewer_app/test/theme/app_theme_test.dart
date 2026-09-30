import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/theme/app_theme.dart';

void main() {
  final theme = AppTheme.dark();

  test('keeps the original AppColors values screens depend on', () {
    expect(AppColors.background, const Color(0xFF0B0B0F));
    expect(AppColors.surface, const Color(0xFF16161C));
    expect(AppColors.surfaceElevated, const Color(0xFF1F1F27));
    expect(AppColors.primary, const Color(0xFFFFCE00));
    expect(AppColors.accent, const Color(0xFF3B82F6));
    expect(AppColors.success, const Color(0xFF22C55E));
    expect(AppColors.danger, const Color(0xFFEF4444));
    expect(AppColors.textPrimary, const Color(0xFFF5F5F7));
    expect(AppColors.textSecondary, const Color(0xFF9CA3AF));
    expect(AppColors.divider, const Color(0xFF2A2A33));
  });

  test('dark, Material 3, near-black scaffold', () {
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.onPrimary, AppColors.onPrimary);
  });

  test('dividers are subtle, never white', () {
    expect(theme.dividerTheme.color, AppColors.divider);
    expect(theme.dividerTheme.thickness, 1);
    expect(theme.colorScheme.outlineVariant, AppColors.divider);
    expect(theme.dividerColor, AppColors.divider);
  });

  test('uses the platform system font (no hardcoded family)', () {
    // Android (the test default) -> Roboto; iOS -> SF. Proves the family
    // comes from the platform typography, not from AppTheme.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final ios = AppTheme.dark();
      expect(ios.textTheme.bodyMedium!.fontFamily, isNot('Roboto'));
      expect(ios.textTheme.displayMedium!.fontFamily, isNot('Roboto'));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    expect(theme.textTheme.displayMedium!.fontSize, 34);
    expect(theme.textTheme.bodyMedium!.fontSize, 15);
  });

  test('inputs: filled, radius 16, gold focus, danger errors', () {
    final input = theme.inputDecorationTheme;
    expect(input.filled, isTrue);
    final focused = input.focusedBorder! as OutlineInputBorder;
    expect(focused.borderSide.color, AppColors.primary);
    expect(focused.borderSide.width, 1.5);
    expect(focused.borderRadius, AppRadii.brMd);
    final error = input.focusedErrorBorder! as OutlineInputBorder;
    expect(error.borderSide.color, AppColors.danger);
    expect(input.errorMaxLines, 2, reason: 'long Mongolian errors wrap');
  });

  test('input icons turn gold on focus, red on error', () {
    final color = theme.inputDecorationTheme.prefixIconColor!;
    Color resolve(Set<WidgetState> s) =>
        WidgetStateProperty.resolveAs<Color>(color, s);
    expect(resolve({}), AppColors.textSecondary);
    expect(resolve({WidgetState.focused}), AppColors.primary);
    expect(
      resolve({WidgetState.focused, WidgetState.error}),
      AppColors.danger,
    );
  });

  test('app bar has no scroll tint', () {
    expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
    expect(theme.appBarTheme.scrolledUnderElevation, 0);
    expect(theme.appBarTheme.backgroundColor, Colors.transparent);
  });

  test('elevated buttons: gold with black text, muted when disabled', () {
    final style = theme.elevatedButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), AppColors.primary);
    expect(style.foregroundColor!.resolve({}), AppColors.onPrimary);
    expect(
      style.backgroundColor!.resolve({WidgetState.disabled}),
      AppColors.surfaceElevated,
    );
    expect(
      style.foregroundColor!.resolve({WidgetState.disabled}),
      AppColors.textSecondary,
    );
  });

  test('sheets, dialogs, snackbars are on-brand', () {
    expect(theme.bottomSheetTheme.backgroundColor, AppColors.surface);
    expect(theme.bottomSheetTheme.dragHandleColor, AppColors.handle);
    expect(theme.dialogTheme.backgroundColor, AppColors.surface);
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.snackBarTheme.backgroundColor, AppColors.surfaceElevated);
  });

  test('date picker selection is black on gold', () {
    final dp = theme.datePickerTheme;
    expect(
      dp.dayBackgroundColor!.resolve({WidgetState.selected}),
      AppColors.primary,
    );
    expect(
      dp.dayForegroundColor!.resolve({WidgetState.selected}),
      AppColors.onPrimary,
    );
  });

  test('cupertino page transitions on iOS and Android', () {
    final builders = theme.pageTransitionsTheme.builders;
    expect(
        builders[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
    expect(
      builders[TargetPlatform.android],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });

  test('AppLayout constants', () {
    expect(AppLayout.screenPadding, 20);
    expect(AppLayout.minTapTarget, 44);
  });

  testWidgets('AppLayout.scrollBottomPadding adds 24 to the bottom inset',
      (tester) async {
    late double value;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 90)),
        child: Builder(
          builder: (context) {
            value = AppLayout.scrollBottomPadding(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(value, 114);
  });

  testWidgets('AppMotion.reduced follows MediaQuery.disableAnimations',
      (tester) async {
    late bool reduced;
    late Duration d;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            reduced = AppMotion.reduced(context);
            d = AppMotion.duration(context, AppDurations.normal);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(reduced, isTrue);
    expect(d, Duration.zero);

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          reduced = AppMotion.reduced(context);
          return const SizedBox();
        },
      ),
    );
    expect(reduced, isFalse, reason: 'defaults to false');
  });

  group('no M3 purple/blue defaults leak through', () {
    test('every *Container role is on-brand (not the accent blue)', () {
      final c = theme.colorScheme;
      for (final color in [
        c.primaryContainer,
        c.secondaryContainer,
        c.tertiaryContainer,
        c.errorContainer,
      ]) {
        expect(color, isNot(AppColors.accent));
        expect(color, isNot(c.secondary));
      }
      expect(c.secondaryContainer, c.primaryContainer); // deep gold
      expect(c.onSecondaryContainer, AppColors.primaryLight);
      expect(c.surfaceTint, Colors.transparent);
    });

    test('FAB is gold with dark ink, flat', () {
      final fab = theme.floatingActionButtonTheme;
      expect(fab.backgroundColor, AppColors.primary);
      expect(fab.foregroundColor, AppColors.onPrimary);
      expect(fab.elevation, 0);
    });

    test('Slider is gold on a subtle track', () {
      final s = theme.sliderTheme;
      expect(s.activeTrackColor, AppColors.primary);
      expect(s.thumbColor, AppColors.primary);
      expect(s.inactiveTrackColor!.a, lessThan(0.2));
    });

    test('SegmentedButton selected = black on gold', () {
      final style = theme.segmentedButtonTheme.style!;
      expect(
        style.backgroundColor!.resolve({WidgetState.selected}),
        AppColors.primary,
      );
      expect(
        style.foregroundColor!.resolve({WidgetState.selected}),
        AppColors.onPrimary,
      );
      expect(style.minimumSize!.resolve({})!.height, AppLayout.minTapTarget);
    });

    test('selected chips read gold (label + border)', () {
      final chip = theme.chipTheme;
      Color? label(Set<WidgetState> s) =>
          WidgetStateProperty.resolveAs<Color?>(chip.labelStyle!.color, s);
      expect(label({WidgetState.selected}), AppColors.primary);
      expect(label({}), AppColors.textPrimary);
      final side = WidgetStateProperty.resolveAs<BorderSide?>(
        chip.side,
        {WidgetState.selected},
      )!;
      expect(side.color.r, closeTo(AppColors.primary.r, 0.01));
    });

    test('disabled + checked checkbox keeps a visible fill', () {
      final fill = theme.checkboxTheme.fillColor!;
      expect(
        fill.resolve({WidgetState.disabled, WidgetState.selected}),
        isNot(AppColors.surfaceElevated),
      );
      expect(fill.resolve({WidgetState.selected}), AppColors.primary);
    });

    test('BottomNavigationBar + menus are themed', () {
      final nav = theme.bottomNavigationBarTheme;
      expect(nav.backgroundColor, AppColors.surface);
      expect(nav.selectedItemColor, AppColors.primary);
      expect(
        theme.menuTheme.style!.backgroundColor!.resolve({}),
        AppColors.surfaceElevated,
      );
      expect(
        theme.dropdownMenuTheme.menuStyle!.backgroundColor!.resolve({}),
        AppColors.surfaceElevated,
      );
    });
  });

  group('WCAG AA contrast (4.5:1 for text)', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    const surfaces = {
      'background': AppColors.background,
      'surface': AppColors.surface,
      'surfaceElevated': AppColors.surfaceElevated,
    };

    for (final entry in surfaces.entries) {
      test('text colors on ${entry.key}', () {
        expect(contrast(AppColors.textPrimary, entry.value),
            greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.textSecondary, entry.value),
            greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.textTertiary, entry.value),
            greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.primary, entry.value),
            greaterThanOrEqualTo(4.5));
      });
    }

    test('ink on gold (CTAs, reward chips) across the gradient', () {
      for (final gold in [
        AppColors.primaryLight,
        AppColors.primary,
        AppColors.primaryDeep,
      ]) {
        expect(contrast(AppColors.onPrimary, gold), greaterThanOrEqualTo(7));
      }
    });
  });

  group('themed Material widgets render cleanly on a phone', () {
    Future<void> pumpPhone(
      WidgetTester tester,
      Widget home, {
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: app!,
          ),
          home: home,
        ),
      );
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('NavigationBar at ${scale}x text', (tester) async {
        await pumpPhone(
          tester,
          Scaffold(
            bottomNavigationBar: NavigationBar(
              selectedIndex: 1,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_rounded),
                  label: 'Нүүр',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_rounded),
                  label: 'Хэтэвч',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_rounded),
                  label: 'Профайл',
                ),
              ],
            ),
          ),
          textScale: scale,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('date picker, dialog, sheet and snackbar open without errors',
        (tester) async {
      late BuildContext ctx;
      await pumpPhone(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );

      showDatePicker(
        context: ctx,
        initialDate: DateTime(2000, 6, 15),
        firstDate: DateTime(1940),
        lastDate: DateTime(2013, 12, 31),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      showDialog<void>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Хүсэлт илгээгдлээ'),
          content: const Text('Админ таны мэдээллийг шалгаад баталгаажуулна.'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Болих')),
            ElevatedButton(onPressed: () {}, child: const Text('Ойлголоо')),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      showModalBottomSheet<void>(
        context: ctx,
        showDragHandle: true,
        builder: (_) => const SizedBox(height: 200),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Сүлжээний алдаа гарлаа')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  });

  test('AppShadows.glow scales and clamps opacity', () {
    final g = AppShadows.glow(AppColors.primary);
    expect(g, hasLength(2));
    expect(g.first.color.a, closeTo(0.34, 0.01));
    final none = AppShadows.glow(AppColors.primary, strength: 0);
    expect(none.every((s) => s.color.a == 0), isTrue);
    final huge = AppShadows.glow(AppColors.primary, strength: 100);
    expect(huge.every((s) => s.color.a <= 1), isTrue);
  });
}
