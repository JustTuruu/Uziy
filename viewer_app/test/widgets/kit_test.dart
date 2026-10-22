import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/ui.dart';

/// Pumps [child] inside the real app theme. [reduceMotion] emulates the OS
/// "reduce motion" setting (MediaQuery.disableAnimations).
Future<void> pumpKit(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

Finder _in<T>(Finder parent) =>
    find.descendant(of: parent, matching: find.byType(T));

void main() {
  group('Pressable', () {
    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await pumpKit(
        tester,
        Pressable(onTap: () => taps++, child: const Text('Дар')),
      );
      await tester.tap(find.text('Дар'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('scales down while pressed and springs back', (tester) async {
      await pumpKit(
        tester,
        Pressable(
          onTap: () {},
          child: const SizedBox(width: 100, height: 50),
        ),
      );
      double scale() => tester
          .widget<Transform>(_in<Transform>(find.byType(Pressable)))
          .transform
          .entry(0, 0);

      expect(scale(), 1.0);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(scale(), lessThan(1.0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scale(), closeTo(1.0, 1e-9));
    });

    testWidgets('does not scale under reduce-motion', (tester) async {
      await pumpKit(
        tester,
        Pressable(
          onTap: () {},
          child: const SizedBox(width: 100, height: 50),
        ),
        reduceMotion: true,
      );
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump(const Duration(milliseconds: 300));
      final t =
          tester.widget<Transform>(_in<Transform>(find.byType(Pressable)));
      expect(t.transform.entry(0, 0), 1.0);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('is disabled when onTap and onLongPress are null',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpKit(
        tester,
        const Pressable(semanticLabel: 'Хаах', child: Icon(Icons.close)),
      );
      expect(
        tester.getSemantics(find.byType(Pressable)),
        isSemantics(
          label: 'Хаах',
          isButton: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });
  });

  group('CoinIcon', () {
    testWidgets('the Uziy mark on a flat brand-green disc', (tester) async {
      await pumpKit(tester, const CoinIcon(size: 40));
      final disc = tester
          .widget<DecoratedBox>(_in<DecoratedBox>(find.byType(CoinIcon)).first)
          .decoration as BoxDecoration;
      final light = AppTheme.light().colorScheme;
      expect(disc.color, light.primary);
      expect(disc.gradient, isNull, reason: 'flat, no lit gold');
      expect(disc.boxShadow, isNull);
      final mark = tester.widget<Image>(_in<Image>(find.byType(CoinIcon)));
      expect((mark.image as AssetImage).assetName, CoinIcon.markAssetPath);
      expect(mark.color, light.onPrimary);
      expect(mark.width, 40 * CoinIcon.markScale);
    });

    testWidgets('small coins skip the inner ring', (tester) async {
      CustomPaint paintOf() => tester
          .widget<CustomPaint>(_in<CustomPaint>(find.byType(CoinIcon)).first);
      await pumpKit(tester, const CoinIcon(size: 16));
      expect(paintOf().painter, isNull);
      await pumpKit(tester, const CoinIcon(size: 30));
      expect(paintOf().painter, isNotNull);
    });

    testWidgets('is decorative for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpKit(tester, const CoinIcon(size: 40));
      expect(
        _in<ExcludeSemantics>(find.byType(CoinIcon)),
        findsWidgets,
      );
      semantics.dispose();
    });
  });

  group('AppButton', () {
    testWidgets('tonal: the action colour as a soft wash with its own ink',
        (tester) async {
      await pumpKit(
        tester,
        AppButton(
          label: 'Мөнгө татах',
          variant: AppButtonVariant.tonal,
          onPressed: () {},
        ),
      );
      const c = AppPalette(false);
      final box = tester
          .widget<AnimatedContainer>(find.descendant(
              of: find.byType(AppButton),
              matching: find.byType(AnimatedContainer)))
          .decoration! as BoxDecoration;
      expect(box.color, c.actionWash);
      expect(box.color, isNot(c.primary));
      expect(box.border, isNotNull);
      final label = tester.widget<Text>(find.text('Мөнгө татах'));
      expect(label.style?.color, c.primary);
      final contrast = (c.actionWash.computeLuminance() + 0.05) /
          (c.primary.computeLuminance() + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    });

    testWidgets('trailing icon sits at the right edge, label stays centred',
        (tester) async {
      await pumpKit(
        tester,
        AppButton(
          label: 'Нэвтрэх',
          trailingIcon: AppIcons.next,
          onPressed: () {},
        ),
      );
      final button = tester.getRect(find.byType(AppButton));
      final icon = tester.getRect(find.byIcon(AppIcons.next));
      final label = tester.getCenter(find.text('Нэвтрэх'));
      expect(button.right - icon.right, lessThan(30));
      expect((label.dx - button.center.dx).abs(), lessThan(1));
    });

    testWidgets('trailing icon hides while loading', (tester) async {
      await pumpKit(
        tester,
        AppButton(
          label: 'Нэвтрэх',
          trailingIcon: AppIcons.next,
          loading: true,
          onPressed: () {},
        ),
      );
      expect(find.byIcon(AppIcons.next), findsNothing);
    });

    testWidgets('raised casts a soft offset shadow; flat by default',
        (tester) async {
      List<BoxShadow>? shadowOf(Widget w) {
        final box = tester.widget<AnimatedContainer>(find.descendant(
          of: find.byWidget(w),
          matching: find.byType(AnimatedContainer),
        ));
        return (box.decoration! as BoxDecoration).boxShadow;
      }

      final raised = AppButton(label: 'A', raised: true, onPressed: () {});
      await pumpKit(tester, raised);
      final shadow = shadowOf(raised)!.single;
      expect(shadow.offset.dy, greaterThan(0));
      expect(shadow.blurRadius, greaterThan(0));

      final flat = AppButton(label: 'B', onPressed: () {});
      await pumpKit(tester, flat);
      expect(shadowOf(flat), isNull);
    });

    testWidgets('tap fires onPressed', (tester) async {
      var taps = 0;
      await pumpKit(
        tester,
        AppButton(label: 'Нэвтрэх', onPressed: () => taps++),
      );
      await tester.tap(find.text('Нэвтрэх'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('loading shows a spinner and blocks taps', (tester) async {
      var taps = 0;
      await pumpKit(
        tester,
        AppButton(label: 'Нэвтрэх', onPressed: () => taps++, loading: true),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Нэвтрэх'), findsNothing);
      await tester.tap(find.byType(AppButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 0);
    });

    testWidgets(
        'is disabled (muted, no gold, not tappable) when onPressed is '
        'null', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpKit(
        tester,
        const AppButton(label: 'Илгээх', onPressed: null),
      );
      final pressable = tester.widget<Pressable>(
        _in<Pressable>(find.byType(AppButton)),
      );
      expect(pressable.onTap, isNull);

      final box = tester.widget<AnimatedContainer>(
        _in<AnimatedContainer>(find.byType(AppButton)),
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, AppColors.surfaceElevated);
      expect(deco.gradient, isNull);
      expect(deco.boxShadow, isNull);

      expect(
        tester.getSemantics(find.byType(Pressable)),
        isSemantics(
          label: 'Илгээх',
          isButton: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('enabled primary is flat gold: no gradient, no glow',
        (tester) async {
      await pumpKit(tester, AppButton(label: 'Үргэлжлүүлэх', onPressed: () {}));
      final box = tester.widget<AnimatedContainer>(
        _in<AnimatedContainer>(find.byType(AppButton)),
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, AppColors.primary);
      expect(deco.gradient, isNull);
      expect(deco.boxShadow, isNull);
    });

    testWidgets('heights: 54 normal, 44 small; expand=false hugs content',
        (tester) async {
      await pumpKit(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(label: 'A', onPressed: () {}),
            AppButton(
              label: 'B',
              onPressed: () {},
              size: AppButtonSize.small,
              expand: false,
            ),
          ],
        ),
      );
      expect(find.byType(AppButton), findsNWidgets(2));
      final a = tester.getSize(find.byType(AppButton).first);
      final b = tester.getSize(find.byType(AppButton).last);
      expect(a.height, 54);
      expect(a.width, 800); // default test surface width
      expect(b.height, 44); // small still meets the 44pt tap target
      expect(b.width, lessThan(200));
      expect(b.width, greaterThanOrEqualTo(44));
    });
  });

  group('AppIconButton', () {
    testWidgets('keeps a 44pt tap target, has a label, fires', (tester) async {
      var taps = 0;
      final handle = tester.ensureSemantics();
      await pumpKit(
        tester,
        AppIconButton(
          icon: Icons.close,
          semanticLabel: 'Хаах',
          size: 32,
          onPressed: () => taps++,
        ),
      );
      final size = tester.getSize(find.byType(AppIconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(find.byType(Pressable)),
        isSemantics(label: 'Хаах', isButton: true, hasTapAction: true),
      );
      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
      handle.dispose();
    });
  });

  group('Coin + RewardChip', () {
    testWidgets('CoinIcon paints at the requested size', (tester) async {
      await pumpKit(tester, const CoinIcon(size: 24));
      expect(tester.getSize(find.byType(CoinIcon)), const Size(24, 24));
      await pumpKit(tester, const CoinIcon(size: 12));
      expect(tester.getSize(find.byType(CoinIcon)), const Size(12, 12));
    });

    testWidgets('RewardChip shows the signed amount with a coin',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpKit(tester, const RewardChip(amount: 700));
      expect(find.text('+700 ₮'), findsOneWidget);
      expect(_in<CoinIcon>(find.byType(RewardChip)), findsOneWidget);
      expect(find.bySemanticsLabel('Урамшуулал +700 ₮'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('RewardChip formats doubles and every size renders',
        (tester) async {
      await pumpKit(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RewardChip(amount: 1250.0, size: RewardChipSize.small),
            RewardChip(amount: 500, size: RewardChipSize.medium),
            RewardChip(amount: 700, size: RewardChipSize.large),
          ],
        ),
      );
      expect(find.text('+1,250 ₮'), findsOneWidget);
      expect(find.text('+500 ₮'), findsOneWidget);
      expect(find.text('+700 ₮'), findsOneWidget);
      final small = tester.getSize(find.byType(RewardChip).at(0)).height;
      final large = tester.getSize(find.byType(RewardChip).at(2)).height;
      expect(large, greaterThan(small));
    });
  });

  group('AnimatedMoney', () {
    testWidgets('counts up and settles on the final formatted value',
        (tester) async {
      await pumpKit(tester, const AnimatedMoney(value: 3400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('3,400 ₮'), findsNothing); // still counting
      await tester.pumpAndSettle();
      expect(find.text('3,400 ₮'), findsOneWidget);
    });

    testWidgets('animates from the previous value to a new one',
        (tester) async {
      var value = 3400;
      late StateSetter setOuter;
      await pumpKit(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return AnimatedMoney(value: value, withSign: true);
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('+3,400 ₮'), findsOneWidget);

      setOuter(() => value = 4100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Mid-roll: an odometer from 3,400 (not from zero) to 4,100.
      final odo = tester.widget<OdometerText>(find.byType(OdometerText));
      expect(odo.from, '+3,400 ₮');
      expect(odo.to, '+4,100 ₮');
      expect(odo.rising, isTrue);
      expect(find.text('+4,100 ₮'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('+4,100 ₮'), findsOneWidget);
    });

    testWidgets('with a memory key an unchanged amount appears at once',
        (tester) async {
      MoneyMemory.clear();
      addTearDown(MoneyMemory.clear);
      const money = AnimatedMoney(value: 3400, memoryKey: 'test');

      await pumpKit(tester, money);
      expect(find.text('3,400 ₮'), findsOneWidget,
          reason: 'first time ever: no count-up from 0');

      await pumpKit(tester, const SizedBox());
      await pumpKit(tester, money); // e.g. back on the wallet tab
      expect(find.text('3,400 ₮'), findsOneWidget);
      expect(tester.widget<OdometerText>(find.byType(OdometerText)).from,
          '3,400 ₮',
          reason: 'nothing to roll');
    });

    testWidgets('with a memory key a new amount rolls from the last one shown',
        (tester) async {
      MoneyMemory.clear();
      addTearDown(MoneyMemory.clear);
      await pumpKit(
          tester, const AnimatedMoney(value: 2700, memoryKey: 'test'));
      await pumpKit(tester, const SizedBox());

      await pumpKit(
          tester, const AnimatedMoney(value: 3400, memoryKey: 'test'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<OdometerText>(find.byType(OdometerText)).from,
          '2,700 ₮');
      await tester.pumpAndSettle();
      expect(find.text('3,400 ₮'), findsOneWidget);
      expect(MoneyMemory.lastShown('test'), 3400);
    });

    testWidgets('the odometer rolls only the digits that changed',
        (tester) async {
      await pumpKit(
        tester,
        const OdometerText(
          from: '2,700 ₮',
          to: '3,400 ₮',
          progress: 0.5,
          style: TextStyle(fontSize: 20),
        ),
      );
      // '2'→'3' and '7'→'4' roll; ',', '00', ' ₮' stay put.
      expect(
        find.descendant(
            of: find.byType(OdometerText), matching: find.byType(ClipRect)),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a longer amount grows its new leading digits in',
        (tester) async {
      await pumpKit(
        tester,
        const OdometerText(
          from: '999 ₮',
          to: '1,000 ₮',
          progress: 0.4,
          style: TextStyle(fontSize: 20),
        ),
      );
      expect(tester.takeException(), isNull);
      await pumpKit(
        tester,
        const OdometerText(
          from: '999 ₮',
          to: '1,000 ₮',
          progress: 1,
          style: TextStyle(fontSize: 20),
        ),
      );
      expect(find.text('1,000 ₮'), findsOneWidget);
    });

    testWidgets('reduce-motion shows the final value immediately, prefix ok',
        (tester) async {
      await pumpKit(
        tester,
        const AnimatedMoney(value: 3400, prefix: 'Үлдэгдэл '),
        reduceMotion: true,
      );
      expect(find.text('Үлдэгдэл 3,400 ₮'), findsOneWidget);
    });

    testWidgets('uses tabular figures', (tester) async {
      await pumpKit(
        tester,
        const AnimatedMoney(
          value: 10,
          animateOnMount: false,
          style: TextStyle(fontSize: 20),
        ),
      );
      final text = tester.widget<Text>(find.text('10 ₮'));
      expect(
        text.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('campaignPalette', () {
    test('is deterministic', () {
      for (final seed in [0, 1, 2, 7, 42, 1000]) {
        expect(campaignPalette(seed), same(campaignPalette(seed)));
        expect(campaignPalette(seed), campaignPalette(seed));
      }
    });

    test('stays in range for negative and huge seeds', () {
      const minInt = -9223372036854775807 - 1;
      const maxInt = 9223372036854775807;
      for (final seed in [
        0,
        -1,
        -7,
        -8,
        -123456789,
        1 << 40,
        -(1 << 40),
        maxInt,
        minInt,
      ]) {
        final p = campaignPalette(seed);
        expect(AppGradients.campaignPalettes, contains(same(p)),
            reason: 'seed $seed');
        expect(p, hasLength(3));
      }
    });

    test('consecutive campaign ids get different palettes', () {
      for (var id = 0; id < 20; id++) {
        expect(campaignPalette(id), isNot(same(campaignPalette(id + 1))));
      }
    });
  });

  group('CampaignArt', () {
    testWidgets('without a thumbnail renders the generated monogram art',
        (tester) async {
      await pumpKit(
        tester,
        const SizedBox(
          width: 320,
          height: 180,
          child: CampaignArt(campaignId: 1, companyName: 'MobiCom'),
        ),
      );
      expect(find.text('M'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.getSize(find.byType(CampaignArt)), const Size(320, 180));
    });

    testWidgets('blank thumbnail url is treated as none; Cyrillic monogram',
        (tester) async {
      await pumpKit(
        tester,
        const SizedBox(
          width: 320,
          height: 180,
          child: CampaignArt(
            campaignId: -3,
            companyName: 'голомт',
            thumbnailUrl: '  ',
            hasVideo: false,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
      );
      expect(find.text('Г'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('GroupedCard + InfoRow', () {
    testWidgets('inserts n-1 dividers', (tester) async {
      await pumpKit(
        tester,
        const GroupedCard(
          children: [
            InfoRow(icon: Icons.male, label: 'Хүйс', value: 'Эрэгтэй'),
            InfoRow(icon: Icons.cake_outlined, label: 'Нас', value: '24'),
            InfoRow(
              icon: Icons.location_city_outlined,
              label: 'Хот',
              value: 'Улаанбаатар',
            ),
          ],
        ),
      );
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.text('Эрэгтэй'), findsOneWidget);
      expect(find.text('Улаанбаатар'), findsOneWidget);
    });

    List<Widget> rows(int n) => [
          for (var i = 0; i < n; i++)
            InfoRow(icon: Icons.history, label: 'Мөр $i'),
        ];

    testWidgets(
        'maxHeight: a long list scrolls inside a card that keeps '
        'its height', (tester) async {
      await pumpKit(tester, GroupedCard(maxHeight: 200, children: rows(20)));

      expect(tester.getSize(find.byType(GroupedCard)).height, 200);
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(find.text('Мөр 19').hitTestable(), findsNothing);

      await tester.dragUntilVisible(
        find.text('Мөр 19'),
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );
      expect(find.text('Мөр 19').hitTestable(), findsOneWidget);
      expect(tester.getSize(find.byType(GroupedCard)).height, 200);
    });

    // Regression (owner, 2026-10-21): on iPhone the box bounced past its ends
    // and the iOS scrollbar shrank and grew with the overscroll, so the
    // indicator looked like it changed size while scrolling up and down.
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets(
          'maxHeight: never scrolls past its ends, so the bar keeps its '
          'length (${platform.name})', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          await pumpKit(
              tester, GroupedCard(maxHeight: 200, children: rows(20)));
          final position = tester
              .state<ScrollableState>(find.descendant(
                  of: find.byType(GroupedCard),
                  matching: find.byType(Scrollable)))
              .position;

          // Pull down at the top, holding the finger there.
          final top = await tester
              .startGesture(tester.getCenter(find.byType(GroupedCard)));
          await top.moveBy(const Offset(0, 40));
          await top.moveBy(const Offset(0, 120));
          await tester.pump();
          expect(position.pixels, 0, reason: 'no overscroll above the top');
          await top.up();
          await tester.pumpAndSettle();

          // Jump to the end and push further up.
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();
          final bottom = await tester
              .startGesture(tester.getCenter(find.byType(GroupedCard)));
          await bottom.moveBy(const Offset(0, -40));
          await bottom.moveBy(const Offset(0, -120));
          await tester.pump();
          expect(position.pixels, position.maxScrollExtent,
              reason: 'no overscroll below the end');
          await bottom.up();
          await tester.pumpAndSettle();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    // Regression (owner, 2026-10-21): inside a page the screen's bottom
    // padding (floating nav bar + home indicator) was taken off the box's
    // scrollbar track, so the bar was too short and stopped ~100pt above the
    // end of the list.
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets(
          'maxHeight: the bar runs the full box height despite the page '
          'padding (${platform.name})', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          const boxHeight = 200.0;
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light(),
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 50, bottom: 120),
              ),
              child: app!,
            ),
            home: Scaffold(
              body: Center(
                child: GroupedCard(maxHeight: boxHeight, children: rows(20)),
              ),
            ),
          ));

          Rect? thumb;
          void readThumb() {
            thumb = null;
            expect(
              find.byType(GroupedCard),
              paints
                ..everything((method, args) {
                  if (method == #drawRRect && (args[0] as RRect).width < 12) {
                    thumb = (args[0] as RRect).outerRect;
                  }
                  return true;
                }),
            );
          }

          // The painter draws in the box's own coordinates: 0..boxHeight.
          // Drag to the very end of the list.
          for (var i = 0; i < 12; i++) {
            await tester.drag(find.byType(GroupedCard), const Offset(0, -150));
            await tester.pump();
          }
          await tester.pumpAndSettle();
          readThumb();
          expect(thumb, isNotNull);
          expect(thumb!.bottom, closeTo(boxHeight, 8),
              reason: 'at the end the bar reaches the bottom of the box');

          // Back to the top: it starts at the top of the box.
          for (var i = 0; i < 12; i++) {
            await tester.drag(find.byType(GroupedCard), const Offset(0, 150));
            await tester.pump();
          }
          await tester.pumpAndSettle();
          readThumb();
          expect(thumb!.top, closeTo(0, 8),
              reason: 'at the start the bar touches the top of the box');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('maxHeight: short content keeps its natural height',
        (tester) async {
      await pumpKit(tester, GroupedCard(maxHeight: 400, children: rows(2)));

      expect(tester.getSize(find.byType(GroupedCard)).height, lessThan(400));
      expect(find.text('Мөр 1').hitTestable(), findsOneWidget);
    });

    testWidgets('without maxHeight nothing scrolls', (tester) async {
      await pumpKit(tester, GroupedCard(children: rows(3)));

      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('single child -> no dividers', (tester) async {
      await pumpKit(
        tester,
        const GroupedCard(
          children: [InfoRow(icon: Icons.male, label: 'Хүйс')],
        ),
      );
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('tappable row fires and shows a chevron', (tester) async {
      var taps = 0;
      await pumpKit(
        tester,
        GroupedCard(
          children: [
            InfoRow(
              icon: Icons.logout,
              label: 'Гарах',
              danger: true,
              onTap: () => taps++,
            ),
            const InfoRow(icon: Icons.male, label: 'Хүйс'),
          ],
        ),
      );
      expect(find.byIcon(AppIcons.chevron), findsOneWidget);
      await tester.tap(find.text('Гарах'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      final label = tester.widget<Text>(find.text('Гарах'));
      expect(label.style!.color, AppColors.danger);
    });
  });

  group('SegmentedProgress', () {
    testWidgets('renders total segments', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpKit(
        tester,
        const SizedBox(
          width: 300,
          child: SegmentedProgress(total: 4, current: 1),
        ),
      );
      expect(
        _in<AnimatedContainer>(find.byType(SegmentedProgress)),
        findsNWidgets(4),
      );
      expect(find.bySemanticsLabel('Явц: 2/4'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('fills completed / active segments and leaves the rest empty',
        (tester) async {
      await pumpKit(
        tester,
        const SizedBox(
          width: 300,
          child: SegmentedProgress(
            total: 3,
            current: 1,
            completedColor: AppColors.success,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final colors = tester
          .widgetList<AnimatedContainer>(
            _in<AnimatedContainer>(find.byType(SegmentedProgress)),
          )
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();
      expect(colors[0], AppColors.success);
      expect(colors[1], AppColors.primary);

      final fills = tester
          .widgetList<AnimatedFractionallySizedBox>(
            _in<AnimatedFractionallySizedBox>(find.byType(SegmentedProgress)),
          )
          .map((f) => f.widthFactor)
          .toList();
      expect(fills, [1, 1, 0]);
    });

    testWidgets('currentFill part-fills only the active segment',
        (tester) async {
      await pumpKit(
        tester,
        const SizedBox(
          width: 320,
          child: SegmentedProgress(
            total: 4,
            current: 1,
            gap: 0,
            currentFill: 0.25,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 4 segments of 80pt each: full, a quarter, empty, empty.
      final widths = tester
          .widgetList<AnimatedContainer>(
            _in<AnimatedContainer>(find.byType(SegmentedProgress)),
          )
          .map((c) => tester.getSize(find.byWidget(c)).width)
          .toList();
      expect(widths, [80, 20, 0, 0]);
    });

    testWidgets('the active fill grows when currentFill goes up',
        (tester) async {
      Widget bar(double fill) => SizedBox(
            width: 300,
            child: SegmentedProgress(
              total: 1,
              current: 0,
              currentFill: fill,
            ),
          );
      double width() => tester
          .getSize(_in<AnimatedContainer>(find.byType(SegmentedProgress)))
          .width;

      await pumpKit(tester, bar(0.3));
      await tester.pumpAndSettle();
      expect(width(), moreOrLessEquals(90));

      await pumpKit(tester, bar(1));
      await tester.pump(const Duration(milliseconds: 60));
      expect(width(), allOf(greaterThan(90), lessThan(300)));
      await tester.pumpAndSettle();
      expect(width(), moreOrLessEquals(300));
    });

    test('fillOf: done 1, active currentFill, upcoming 0', () {
      const bar = SegmentedProgress(total: 3, current: 1, currentFill: 0.4);
      expect(bar.fillOf(0), 1);
      expect(bar.fillOf(1), 0.4);
      expect(bar.fillOf(2), 0);
    });

    testWidgets('total 0 renders no segments', (tester) async {
      await pumpKit(tester, const SegmentedProgress(total: 0, current: 0));
      expect(
        _in<AnimatedContainer>(find.byType(SegmentedProgress)),
        findsNothing,
      );
    });
  });

  group('ConfettiBurst', () {
    testWidgets('plays without exceptions, then disappears', (tester) async {
      var completed = 0;
      await pumpKit(
        tester,
        SizedBox(
          width: 400,
          height: 800,
          child: Stack(
            children: [
              Positioned.fill(
                child: ConfettiBurst(onComplete: () => completed++),
              ),
            ],
          ),
        ),
      );
      final paint = _in<CustomPaint>(find.byType(ConfettiBurst));
      expect(paint, findsOneWidget);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(_in<CustomPaint>(find.byType(ConfettiBurst)), findsNothing);
      expect(completed, 1);
    });

    testWidgets('does not block taps underneath', (tester) async {
      var taps = 0;
      await pumpKit(
        tester,
        SizedBox(
          width: 400,
          height: 400,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                ),
              ),
              const Positioned.fill(child: ConfettiBurst()),
            ],
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byType(ConfettiBurst)));
      expect(taps, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('renders nothing under reduce-motion but still completes',
        (tester) async {
      var completed = 0;
      await pumpKit(
        tester,
        SizedBox(
          width: 400,
          height: 400,
          child: ConfettiBurst(onComplete: () => completed++),
        ),
        reduceMotion: true,
      );
      expect(_in<CustomPaint>(find.byType(ConfettiBurst)), findsNothing);
      await tester.pump();
      expect(completed, 1);
    });

    testWidgets('play=false renders nothing', (tester) async {
      await pumpKit(
        tester,
        const SizedBox(
          width: 400,
          height: 400,
          child: ConfettiBurst(play: false),
        ),
      );
      expect(_in<CustomPaint>(find.byType(ConfettiBurst)), findsNothing);
    });
  });

  group('EmptyState', () {
    testWidgets('renders texts and the action fires', (tester) async {
      var taps = 0;
      await pumpKit(
        tester,
        EmptyState(
          icon: Icons.video_library_outlined,
          title: 'Одоогоор видео алга',
          message: 'Удахгүй шинэ видео нэмэгдэнэ.',
          action: AppButton(
            label: 'Шинэчлэх',
            expand: false,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.text('Одоогоор видео алга'), findsOneWidget);
      expect(find.text('Удахгүй шинэ видео нэмэгдэнэ.'), findsOneWidget);
      await tester.tap(find.text('Шинэчлэх'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('StatusBanner', () {
    testWidgets('renders title + message and the action fires', (tester) async {
      var retries = 0;
      await pumpKit(
        tester,
        StatusBanner(
          title: 'Алдаа',
          message: 'Сервертэй холбогдож чадсангүй',
          actionLabel: 'Дахин',
          onAction: () => retries++,
        ),
      );
      expect(find.text('Алдаа'), findsOneWidget);
      expect(find.text('Сервертэй холбогдож чадсангүй'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      await tester.tap(find.text('Дахин'));
      await tester.pumpAndSettle();
      expect(retries, 1);
    });

    testWidgets('no action label -> no action; tones pick icons',
        (tester) async {
      await pumpKit(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBanner(message: 'Мэдээлэл', tone: BannerTone.info),
            StatusBanner(message: 'Амжилттай', tone: BannerTone.success),
            StatusBanner(message: 'Анхаар', tone: BannerTone.warning),
          ],
        ),
      );
      expect(find.byType(Pressable), findsNothing);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('small kit pieces', () {
    testWidgets('TagChip, SectionHeader render their content', (tester) async {
      await pumpKit(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TagChip(label: '45 сек', icon: Icons.schedule, tone: TagTone.glass),
            TagChip(label: 'Судалгаа', tone: TagTone.gold),
            SectionHeader(
              title: 'Гүйлгээний түүх',
              subtitle: 'Сүүлийн 30 хоног',
              trailing: TagChip(label: '3'),
            ),
          ],
        ),
      );
      expect(find.text('45 сек'), findsOneWidget);
      expect(find.text('Судалгаа'), findsOneWidget);
      expect(find.text('Гүйлгээний түүх'), findsOneWidget);
      expect(find.text('Сүүлийн 30 хоног'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('AppCard: tappable only with onTap', (tester) async {
      var taps = 0;
      await pumpKit(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppCard(onTap: () => taps++, child: const Text('Карт')),
            const AppCard(
              gradient: AppGradients.gold,
              child: Text('Алтан'),
            ),
          ],
        ),
      );
      expect(_in<Pressable>(find.byType(AppCard).first), findsOneWidget);
      expect(_in<Pressable>(find.byType(AppCard).last), findsNothing);
      await tester.tap(find.text('Карт'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('AmbientBackground paints behind and never eats taps',
        (tester) async {
      var taps = 0;
      await pumpKit(
        tester,
        SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                ),
              ),
              const Positioned.fill(
                child: AmbientBackground(
                  variant: AmbientVariant.gold,
                  child: SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byType(AmbientBackground)));
      expect(taps, 1);
    });

    testWidgets('AmbientBackground variants render a child', (tester) async {
      for (final v in AmbientVariant.values) {
        await pumpKit(
          tester,
          AmbientBackground(variant: v, child: const Text('Uziy')),
        );
        expect(find.text('Uziy'), findsOneWidget);
      }
    });

    testWidgets('SkeletonShimmer animates; static under reduce-motion',
        (tester) async {
      await pumpKit(
        tester,
        const SkeletonShimmer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Skeleton(width: 200, height: 16),
              Skeleton(width: 120, height: 12, radius: 6),
            ],
          ),
        ),
      );
      expect(find.byType(ShaderMask), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);

      await pumpKit(
        tester,
        const SkeletonShimmer(child: Skeleton(width: 100)),
        reduceMotion: true,
      );
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('FadeSlideIn ends fully visible; skipped under reduce-motion',
        (tester) async {
      await pumpKit(
        tester,
        const FadeSlideIn(index: 3, child: Text('Сайн уу')),
      );
      final fade = tester.widget<FadeTransition>(
        _in<FadeTransition>(find.byType(FadeSlideIn)),
      );
      expect(fade.opacity.value, 0);
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
      expect(find.text('Сайн уу'), findsOneWidget);

      await pumpKit(
        tester,
        const FadeSlideIn(key: ValueKey('reduced'), child: Text('Шууд')),
        reduceMotion: true,
      );
      expect(_in<FadeTransition>(find.byType(FadeSlideIn)), findsNothing);
      expect(find.text('Шууд'), findsOneWidget);
    });

    testWidgets('UziyLogo renders the logo asset with a label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpKit(tester, const UziyLogo(size: 80));
      expect(tester.getSize(find.byType(UziyLogo)), const Size(80, 80));
      expect(find.byType(Image), findsOneWidget);
      expect(find.bySemanticsLabel('Uziy'), findsOneWidget);
      handle.dispose();
    });

    for (final dark in [false, true]) {
      testWidgets(
          'UziyWordmark tints the mark and name with the text colour '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: const Scaffold(body: Center(child: UziyWordmark())),
        ));
        final expected = AppPalette(dark).textPrimary;
        final mark = tester.widget<Image>(find.byType(Image));
        expect(mark.color, expected);
        expect(mark.colorBlendMode, BlendMode.srcIn);
        final name = tester.widget<Text>(find.text(UziyWordmark.name));
        expect(name.style?.color, expected);
        expect(tester.getSize(find.byType(Image)).height, 28);
      });
    }
  });

  group('RewardChip colours (owner, 2026-10-21: no loud gold)', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    for (final dark in [false, true]) {
      test('${dark ? 'dark' : 'light'}: a soft action wash with AA ink', () {
        final c = AppPalette(dark);
        final fill = RewardChip.fillIn(c);
        expect(fill, isNot(const Color(0xFFF2D48A)));
        expect(contrast(RewardChip.inkIn(c), fill), greaterThanOrEqualTo(4.5));
      });
    }

    testWidgets('no glow, a hairline instead', (tester) async {
      await pumpKit(tester, const RewardChip(amount: 700));
      final box = tester
          .widget<Container>(find.descendant(
              of: find.byType(RewardChip), matching: find.byType(Container)))
          .decoration! as BoxDecoration;
      expect(box.boxShadow, isNull);
      expect(box.border, isNotNull);
    });
  });
}
