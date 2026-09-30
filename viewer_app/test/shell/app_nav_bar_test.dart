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

/// Alpha (0..1) of the label text color, i.e. how visible the label is.
/// Labels are drawn in two masked layers (outside / inside the gold
/// capsule) that always share the same alpha.
double _labelAlpha(WidgetTester tester, String label) {
  final alphas = tester
      .widgetList<Text>(find.text(label))
      .map((t) => t.style!.color!.a)
      .toSet();
  expect(alphas, hasLength(1));
  return alphas.single;
}

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

  group('AppNavBar.weightsAt', () {
    test('interpolates from the old selection to the new one', () {
      expect(AppNavBar.weightsAt(const [1, 0, 0], 2, 0), [1, 0, 0]);
      expect(AppNavBar.weightsAt(const [1, 0, 0], 2, 0.5), [0.5, 0, 0.5]);
      expect(AppNavBar.weightsAt(const [1, 0, 0], 2, 1), [0, 0, 1]);
    });

    test('clamps progress and resumes from mixed weights', () {
      expect(AppNavBar.weightsAt(const [1, 0, 0], 1, 3), [0, 1, 0]);
      expect(AppNavBar.weightsAt(const [1, 0, 0], 1, -1), [1, 0, 0]);
      expect(AppNavBar.weightsAt(const [0.5, 0.5, 0], 2, 0.5), [
        0.25,
        0.25,
        0.5,
      ]);
    });
  });

  group('AppNavBar.itemWidths', () {
    test('selected item gets the bonus, the rest is shared evenly', () {
      // 300 - 3 * 56 = 132 spare; bonus capped at 96; base (300 - 96) / 3.
      final widths = AppNavBar.itemWidths(300, const [1, 0, 0]);
      expect(widths, [164, 68, 68]);
      expect(widths.reduce((a, b) => a + b), 300);
    });

    test('bonus shrinks to the spare room on narrow bars', () {
      // 200 - 168 = 32 spare: all of it goes to the selected item.
      expect(AppNavBar.itemWidths(200, const [0, 1, 0]), [56, 88, 56]);
    });

    test('splits the bonus by weight mid-animation', () {
      final widths = AppNavBar.itemWidths(300, const [0.5, 0, 0.5]);
      expect(widths, [116, 68, 116]);
    });

    test('never collapses below 44pt and splits evenly when too narrow', () {
      expect(AppNavBar.collapsedItemWidth, greaterThanOrEqualTo(44));
      expect(AppNavBar.itemWidths(120, const [1, 0, 0]), [40, 40, 40]);
    });

    test('handles empty, zero and negative weights', () {
      expect(AppNavBar.itemWidths(300, const []), isEmpty);
      expect(AppNavBar.itemWidths(300, const [0, 0, 0]), [100, 100, 100]);
      expect(AppNavBar.itemWidths(300, const [-1, 1, 0]), [68, 164, 68]);
      expect(
        AppNavBar.itemWidths(double.infinity, const [1, 0]),
        [0, 0],
      );
    });
  });

  group('AppNavBar.indicatorRect', () {
    test('covers the selected item exactly when settled', () {
      expect(
        AppNavBar.indicatorRect(const [188, 56, 56], const [1, 0, 0], 52),
        const Rect.fromLTWH(0, 0, 188, 52),
      );
      expect(
        AppNavBar.indicatorRect(const [56, 56, 188], const [0, 0, 1], 52),
        const Rect.fromLTWH(112, 0, 188, 52),
      );
    });

    test('slides between the two items mid-animation', () {
      expect(
        AppNavBar.indicatorRect(const [122, 56, 122], const [0.5, 0, 0.5], 52),
        const Rect.fromLTWH(89, 0, 122, 52),
      );
    });

    test('is empty when nothing is selected', () {
      expect(
        AppNavBar.indicatorRect(const [100, 100], const [0, 0], 52).width,
        0,
      );
    });
  });

  group('AppNavBar widget', () {
    testWidgets('renders every label; only the selected one is shown', (
      tester,
    ) async {
      await _pumpBar(tester, index: 1);

      for (final item in _items) {
        expect(find.text(item.label), findsWidgets);
      }
      expect(_labelAlpha(tester, 'Хэтэвч'), 1);
      expect(_labelAlpha(tester, 'Нүүр'), 0);
      expect(_labelAlpha(tester, 'Профайл'), 0);
      // The selected (filled) icon is used for the active tab.
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsWidgets);
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

    testWidgets('animates the capsule to the new selection', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpBar(tester, index: 0);
      final homeBefore = tester.getSize(find.bySemanticsLabel('Нүүр')).width;

      await _pumpBar(tester, index: 2);
      // Mid-flight: still animating, both items partly open.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      final homeMid = tester.getSize(find.bySemanticsLabel('Нүүр')).width;
      final walletMid = tester.getSize(find.bySemanticsLabel('Хэтэвч')).width;
      expect(homeMid, lessThan(homeBefore));
      expect(homeMid, greaterThan(walletMid));

      await tester.pumpAndSettle();
      expect(_labelAlpha(tester, 'Профайл'), 1);
      expect(_labelAlpha(tester, 'Нүүр'), 0);
      // Unselected items share the same width; the new one took the bonus.
      expect(
        tester.getSize(find.bySemanticsLabel('Нүүр')).width,
        tester.getSize(find.bySemanticsLabel('Хэтэвч')).width,
      );
      expect(
        tester.getSize(find.bySemanticsLabel('Профайл')).width,
        homeBefore,
      );
      semantics.dispose();
    });

    testWidgets('reduce motion switches instantly with no animation', (
      tester,
    ) async {
      await _pumpBar(tester, index: 0, reduceMotion: true);
      await _pumpBar(tester, index: 2, reduceMotion: true);

      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_labelAlpha(tester, 'Профайл'), 1);
      expect(_labelAlpha(tester, 'Нүүр'), 0);
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
      expect(item.bottom, screen.height - gap - AppNavBar.innerPadding);
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
