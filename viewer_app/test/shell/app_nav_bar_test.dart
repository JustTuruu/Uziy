import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/app_nav_bar.dart';
import 'package:viewer_app/widgets/ui.dart';

const _items = [
  AppNavItem(
    icon: Icons.play_circle_outline_rounded,
    selectedIcon: Icons.play_circle_rounded,
    label: 'Нүүр',
  ),
  AppNavItem(
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    label: 'Хэтэвч',
  ),
  AppNavItem(
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: 'Профайл',
  ),
];

/// Built once: AppTheme.dark() returns a fresh ThemeData (with fresh
/// WidgetState closures) on every call, and re-pumping with a non-equal theme
/// would start an AnimatedTheme transition that masks our own animations.
final _theme = AppTheme.dark();

/// Pumps the bar the way the main shell uses it:
/// `Scaffold(extendBody: true, bottomNavigationBar: AppNavBar(...))`.
Future<void> _pumpBar(
  WidgetTester tester, {
  int index = 0,
  ValueChanged<int>? onTap,
  bool reduceMotion = false,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  Widget? body,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
          padding: padding,
          viewPadding: padding,
        ),
        child: child!,
      ),
      home: Scaffold(
        extendBody: true,
        body: body ?? const SizedBox.expand(),
        bottomNavigationBar: AppNavBar(
          currentIndex: index,
          onTap: onTap ?? (_) {},
          items: _items,
        ),
      ),
    ),
  );
}

/// Color of the label text.
Color _labelColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

void main() {
  group('AppNavBar.bottomGap', () {
    test('floats 12pt up when there is no bottom inset', () {
      expect(AppNavBar.bottomGap(0), 12);
      expect(AppNavBar.bottomGap(-5), 12);
      expect(AppNavBar.bottomGap(double.nan), 12);
    });

    test('sits just above the home indicator on notched phones', () {
      expect(AppNavBar.bottomGap(34), 26);
      // Small insets never pull the bar closer than 12pt.
      expect(AppNavBar.bottomGap(16), 12);
    });
  });

  group('AppNavBar widget', () {
    testWidgets('every label is always visible; selected one is gold', (
      tester,
    ) async {
      await _pumpBar(tester, index: 1);

      for (final item in _items) {
        expect(find.text(item.label), findsOneWidget);
      }
      expect(_labelColor(tester, 'Хэтэвч'), AppColors.primary);
      expect(_labelColor(tester, 'Нүүр'), AppColors.textSecondary);
      expect(_labelColor(tester, 'Профайл'), AppColors.textSecondary);
      // Filled icon for the active tab, outlined for the rest.
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('label sits below its icon', (tester) async {
      await _pumpBar(tester, index: 0);
      final icon = tester.getRect(find.byIcon(Icons.play_circle_rounded));
      final label = tester.getRect(find.text('Нүүр'));
      expect(label.top, greaterThanOrEqualTo(icon.bottom));
      expect((label.center.dx - icon.center.dx).abs(), lessThan(1));
    });

    testWidgets('items are fixed: equal width, no animation on change', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpBar(tester, index: 0);
      final before = [
        for (final i in _items) tester.getRect(find.bySemanticsLabel(i.label)),
      ];
      expect(before[0].width, before[1].width);
      expect(before[1].width, before[2].width);

      await _pumpBar(tester, index: 2);
      expect(tester.binding.hasScheduledFrame, isFalse);
      final after = [
        for (final i in _items) tester.getRect(find.bySemanticsLabel(i.label)),
      ];
      expect(after, before);
      expect(_labelColor(tester, 'Профайл'), AppColors.primary);
      expect(_labelColor(tester, 'Нүүр'), AppColors.textSecondary);
      semantics.dispose();
    });

    testWidgets('exposes button + selected semantics per item', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpBar(tester, index: 0);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Нүүр')),
        isSemantics(
          label: 'Нүүр',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      for (final label in ['Хэтэвч', 'Профайл']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(
            label: label,
            isButton: true,
            isSelected: false,
            hasTapAction: true,
          ),
        );
      }
      semantics.dispose();
    });

    testWidgets('tap calls onTap with the index (reselect included)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final taps = <int>[];
      await _pumpBar(tester, index: 0, onTap: taps.add);

      await tester.tap(find.bySemanticsLabel('Профайл'));
      await tester.tap(find.bySemanticsLabel('Хэтэвч'));
      await tester.tap(find.bySemanticsLabel('Нүүр'));
      await tester.pumpAndSettle();

      expect(taps, [2, 1, 0]);
      semantics.dispose();
    });

    testWidgets('selection click haptic only when the tab changes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pumpBar(tester, index: 0);

      await tester.tap(find.bySemanticsLabel('Хэтэвч'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);

      await tester.tap(find.bySemanticsLabel('Нүүр')); // already selected
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1));
      semantics.dispose();
    });

    testWidgets('floats above the safe area and pads the body for it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      late double bodyBottomPadding;
      await _pumpBar(
        tester,
        padding: const EdgeInsets.only(bottom: 34),
        body: Builder(
          builder: (context) {
            bodyBottomPadding = MediaQuery.paddingOf(context).bottom;
            return const SizedBox.expand();
          },
        ),
      );

      final gap = AppNavBar.bottomGap(34);
      // extendBody folds the bar (pill + gap) into the body's bottom inset,
      // which is what AppLayout.scrollBottomPadding relies on.
      expect(bodyBottomPadding, AppNavBar.barHeight + gap);

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final item = tester.getRect(find.bySemanticsLabel('Нүүр'));
      expect(item.bottom, screen.height - gap);
      expect(item.height, greaterThanOrEqualTo(44));
      semantics.dispose();
    });

    testWidgets('taps beside the pill reach the content underneath', (
      tester,
    ) async {
      var bodyTaps = 0;
      var navTaps = 0;
      await _pumpBar(
        tester,
        onTap: (_) => navTaps++,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => bodyTaps++,
          child: const SizedBox.expand(),
        ),
      );

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      // Left margin (outside the pill) at the bar's vertical center.
      final barCenterY =
          screen.height - AppNavBar.minBottomGap - AppNavBar.barHeight / 2;
      await tester.tapAt(Offset(6, barCenterY));
      await tester.pumpAndSettle();
      expect(bodyTaps, 1);
      expect(navTaps, 0);

      // The pill itself absorbs taps.
      await tester.tapAt(Offset(screen.width / 2, barCenterY));
      await tester.pumpAndSettle();
      expect(bodyTaps, 1);
      expect(navTaps, 1);
    });

    testWidgets('fits a 320pt phone at large text scale without overflow', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(960, 1704);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      for (final scale in [1.3, 2.0]) {
        for (var i = 0; i < _items.length; i++) {
          await _pumpBar(tester, index: i, textScale: scale);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final item in _items) {
            final size = tester.getSize(find.bySemanticsLabel(item.label));
            expect(size.width, greaterThanOrEqualTo(44));
            expect(size.height, greaterThanOrEqualTo(44));
          }
        }
      }
      semantics.dispose();
    });
  });
}
