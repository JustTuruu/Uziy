import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/ui.dart';

/// Adversarial tests for the Gold Noir kit: the ways screen code is likely
/// to misuse it (unbounded constraints, narrow boxes, big OS text, reduce
/// motion, unmounting mid-animation) must never throw.
Future<void> pumpKit(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
  double textScale = 1.0,
  bool center = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
      home: Scaffold(body: center ? Center(child: child) : child),
    ),
  );
}

Finder _in<T>(Finder parent) =>
    find.descendant(of: parent, matching: find.byType(T));

void main() {
  group('FillWidth', () {
    testWidgets('fills a bounded width', (tester) async {
      await pumpKit(
        tester,
        const SizedBox(
          width: 300,
          child: FillWidth(child: SizedBox(height: 10)),
        ),
      );
      expect(tester.getSize(find.byType(FillWidth)), const Size(300, 10));
    });

    testWidgets('hugs its child in an unbounded Row instead of throwing',
        (tester) async {
      await pumpKit(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [FillWidth(child: SizedBox(width: 40, height: 10))],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(FillWidth)), const Size(40, 10));
    });

    testWidgets('uses fallbackWidth when unbounded', (tester) async {
      await pumpKit(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [FillWidth(fallbackWidth: 90, child: SizedBox(height: 8))],
        ),
      );
      expect(tester.getSize(find.byType(FillWidth)).width, 90);
    });

    testWidgets('supports intrinsic sizing (IntrinsicWidth / dialogs)',
        (tester) async {
      await pumpKit(
        tester,
        const IntrinsicWidth(
          child: FillWidth(child: SizedBox(width: 70, height: 10)),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(FillWidth)).width, 70);
    });

    test('dry layout matches real layout rules', () {
      final box = RenderFillWidth(
        child: RenderConstrainedBox(
          additionalConstraints: const BoxConstraints.tightFor(height: 12),
        ),
      );
      expect(
        box.getDryLayout(const BoxConstraints(maxWidth: 200)),
        const Size(200, 12),
      );
      box.fallbackWidth = 50;
      expect(
        box.getDryLayout(const BoxConstraints(maxHeight: 100)),
        const Size(50, 12),
      );
      final empty = RenderFillWidth();
      expect(
        empty.getDryLayout(const BoxConstraints(maxWidth: 80, maxHeight: 5)),
        const Size(80, 0),
      );
    });
  });

  group('AppButton layout safety', () {
    testWidgets('expand:true inside a Row without Expanded does not throw',
        (tester) async {
      await pumpKit(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(label: 'Болих', onPressed: () {}),
            const SizedBox(width: 8),
            AppButton(label: 'Илгээх', onPressed: () {}),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AppButton), findsNWidgets(2));
      // Hugs its label: well under the 800px test surface.
      expect(tester.getSize(find.byType(AppButton).first).width, lessThan(300));
    });

    testWidgets('two expanded buttons share a Row', (tester) async {
      await pumpKit(
        tester,
        SizedBox(
          width: 400,
          child: Row(
            children: [
              Expanded(child: AppButton(label: 'Болих', onPressed: () {})),
              const SizedBox(width: 10),
              Expanded(child: AppButton(label: 'Илгээх', onPressed: () {})),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppButton).first).width, 195);
    });

    testWidgets('works as an AlertDialog action (intrinsic layout)',
        (tester) async {
      await pumpKit(
        tester,
        AlertDialog(
          title: const Text('Хүсэлт илгээгдлээ'),
          actions: [
            AppButton(label: 'Ойлголоо', expand: false, onPressed: () {}),
            AppButton(label: 'Хаах', onPressed: () {}),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Ойлголоо'), findsOneWidget);
    });

    testWidgets('long label ellipsizes in a narrow box, no overflow',
        (tester) async {
      await pumpKit(
        tester,
        SizedBox(
          width: 120,
          child: AppButton(
            label: 'Урамшууллаа хэтэвчиндээ шилжүүлэх',
            icon: Icons.account_balance_wallet_rounded,
            onPressed: () {},
          ),
        ),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Skeleton layout safety', () {
    testWidgets('width:null in an unbounded Row falls back, no throw',
        (tester) async {
      await pumpKit(
        tester,
        const SkeletonShimmer(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Skeleton(width: 48, height: 48, radius: 24),
              SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [Skeleton(), SizedBox(height: 6), Skeleton()],
              ),
            ],
          ),
        ),
        reduceMotion: true,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(Skeleton).at(1)).width,
        Skeleton.unboundedWidth,
      );
    });

    testWidgets('width:null fills a bounded parent', (tester) async {
      await pumpKit(
        tester,
        const SizedBox(width: 260, child: Skeleton(height: 14)),
      );
      expect(tester.getSize(find.byType(Skeleton)), const Size(260, 14));
    });

    testWidgets('shimmer is isolated in a RepaintBoundary', (tester) async {
      await pumpKit(tester, const SkeletonShimmer(child: Skeleton(width: 80)));
      expect(
        find.ancestor(
          of: find.byType(ShaderMask),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
      await tester.pump(const Duration(milliseconds: 500));
      // Unmount mid-sweep: controller must be disposed cleanly.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });

  group('CampaignArt layout safety', () {
    testWidgets('directly in a Column (unbounded height) -> 16:9, no throw',
        (tester) async {
      await pumpKit(
        tester,
        const SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [CampaignArt(campaignId: 2, companyName: 'UniTel')],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CampaignArt)), const Size(320, 180));
    });

    testWidgets('as a ListView item without AspectRatio', (tester) async {
      await pumpKit(
        tester,
        ListView(
          children: const [
            CampaignArt(campaignId: 1, companyName: 'MobiCom'),
            CampaignArt(campaignId: 2, companyName: 'Голомт'),
          ],
        ),
        center: false,
      );
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(CampaignArt).first);
      expect(size.width, 800);
      expect(size.height, closeTo(450, 0.01));
    });

    testWidgets('monogram ignores OS text scaling (it is artwork)',
        (tester) async {
      Future<double> fontAt(double scale) async {
        await pumpKit(
          tester,
          const SizedBox(
            width: 320,
            height: 180,
            child: CampaignArt(campaignId: 1, companyName: 'MobiCom'),
          ),
          textScale: scale,
        );
        final text = tester.widget<Text>(find.text('M'));
        expect(text.textScaler, TextScaler.noScaling);
        return tester.getSize(find.text('M')).height;
      }

      final normal = await fontAt(1.0);
      final big = await fontAt(2.0);
      expect(big, normal);
    });

    testWidgets(
        'network thumbnail: decoded near display size; failure '
        'falls back to generated art without an error', (tester) async {
      await pumpKit(
        tester,
        const SizedBox(
          width: 320,
          height: 180,
          child: CampaignArt(
            campaignId: 5,
            companyName: 'Khan Bank',
            thumbnailUrl: 'https://cdn.example.test/thumb.jpg',
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      final resize = image.image as ResizeImage;
      final dpr = tester.view.devicePixelRatio;
      expect(resize.width, (320 * dpr).round());
      // Test HTTP returns 400 -> errorBuilder -> generated art stays.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('K'), findsOneWidget);
    });

    testWidgets('isolated in a RepaintBoundary, excluded from semantics',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpKit(
        tester,
        const SizedBox(
          width: 320,
          height: 180,
          child: CampaignArt(campaignId: 1, companyName: 'MobiCom'),
        ),
      );
      expect(_in<RepaintBoundary>(find.byType(CampaignArt)), findsWidgets);
      expect(find.bySemanticsLabel('M'), findsNothing);
      handle.dispose();
    });
  });

  group('ConfettiBurst layout safety', () {
    testWidgets('in an unbounded Column takes no space and does not throw',
        (tester) async {
      await pumpKit(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text('Баяр хүргэе'), ConfettiBurst()],
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ConfettiBurst)).height, 0);
      await tester.pumpAndSettle();
    });

    testWidgets('unmounting mid-burst is clean', (tester) async {
      await pumpKit(
        tester,
        const SizedBox(width: 300, height: 300, child: ConfettiBurst()),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('play false -> true replays', (tester) async {
      var completed = 0;
      Widget burst(bool play) => SizedBox(
            width: 300,
            height: 300,
            child: ConfettiBurst(play: play, onComplete: () => completed++),
          );
      await pumpKit(tester, burst(false));
      expect(_in<CustomPaint>(find.byType(ConfettiBurst)), findsNothing);
      await pumpKit(tester, burst(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_in<CustomPaint>(find.byType(ConfettiBurst)), findsOneWidget);
      await tester.pumpAndSettle();
      expect(completed, 1);
    });
  });

  group('FadeSlideIn stagger', () {
    test('staggerSlot is relative to the batch and capped', () {
      expect(FadeSlideIn.staggerSlot(0, 0), 0);
      expect(FadeSlideIn.staggerSlot(3, 0), 3);
      expect(FadeSlideIn.staggerSlot(20, 0), FadeSlideIn.maxStaggerIndex);
      expect(FadeSlideIn.staggerSlot(14, 14), 0);
      expect(FadeSlideIn.staggerSlot(15, 14), 1);
      expect(FadeSlideIn.staggerSlot(2, 5), 0);
    });

    testWidgets('first screenful cascades in index order', (tester) async {
      await pumpKit(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 4; i++)
              FadeSlideIn(index: i, child: Text('Карт $i')),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      double opacityOf(int i) => tester
          .widget<FadeTransition>(
            _in<FadeTransition>(find.byType(FadeSlideIn).at(i)),
          )
          .opacity
          .value;
      expect(opacityOf(0), greaterThan(0));
      expect(opacityOf(0), greaterThan(opacityOf(2)));
      expect(opacityOf(3), 0); // still waiting its turn (165 ms)
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        expect(opacityOf(i), 1);
      }
    });

    testWidgets('an item built later (while scrolling) starts immediately',
        (tester) async {
      await pumpKit(tester, const SizedBox());
      // Alone in its frame, index 14 must not wait 8 * 55 ms.
      await pumpKit(
        tester,
        const FadeSlideIn(index: 14, child: Text('Карт 14')),
      );
      await tester.pump(const Duration(milliseconds: 60));
      final fade = tester.widget<FadeTransition>(
        _in<FadeTransition>(find.byType(FadeSlideIn)),
      );
      expect(fade.opacity.value, greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('unmount mid-animation is clean', (tester) async {
      await pumpKit(tester, const FadeSlideIn(child: Text('Сайн уу')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });

  group('Pressable robustness', () {
    testWidgets('unmount while pressed is clean', (tester) async {
      await pumpKit(
        tester,
        Pressable(onTap: () {}, child: const SizedBox(width: 80, height: 40)),
      );
      final g =
          await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpWidget(const SizedBox());
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('becoming disabled mid-press resets the scale', (tester) async {
      VoidCallback? onTap = () {};
      late StateSetter set;
      await pumpKit(
        tester,
        StatefulBuilder(
          builder: (context, s) {
            set = s;
            return Pressable(
              onTap: onTap,
              child: const SizedBox(width: 80, height: 40),
            );
          },
        ),
      );
      final g =
          await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump(const Duration(milliseconds: 200));
      set(() => onTap = null);
      await tester.pump();
      final t =
          tester.widget<Transform>(_in<Transform>(find.byType(Pressable)));
      expect(t.transform.entry(0, 0), 1.0);
      await g.up();
      await tester.pumpAndSettle();
    });
  });

  group('chips under pressure', () {
    testWidgets('RewardChip clamps OS text scale inside its fixed pill',
        (tester) async {
      await pumpKit(tester, const RewardChip(amount: 700), textScale: 3.0);
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('+700 ₮'));
      expect(text.textScaler!.scale(10), 10 * RewardChip.maxTextScale);
    });

    testWidgets('RewardChip / TagChip ellipsize in a narrow box',
        (tester) async {
      await pumpKit(
        tester,
        const SizedBox(
          width: 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RewardChip(amount: 1234567, size: RewardChipSize.large),
              TagChip(label: 'Маш урт шошго текст', icon: Icons.schedule),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('semantics', () {
    testWidgets('tappable InfoRow is announced as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpKit(
        tester,
        InfoRow(icon: Icons.logout_rounded, label: 'Гарах', onTap: () {}),
      );
      expect(
        tester.getSemantics(find.byType(InfoRow)),
        isSemantics(label: 'Гарах', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('read-only InfoRow is not a button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpKit(
        tester,
        const InfoRow(icon: Icons.male_rounded, label: 'Хүйс', value: 'Эр'),
      );
      expect(
        tester.getSemantics(find.byType(InfoRow)),
        isSemantics(label: 'Хүйс\nЭр', isButton: false),
      );
      handle.dispose();
    });
  });

  group('AppCard', () {
    testWidgets('hairline border sits above full-bleed content',
        (tester) async {
      await pumpKit(
        tester,
        const SizedBox(
          width: 300,
          child: AppCard(
            padding: EdgeInsets.zero,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CampaignArt(campaignId: 1, companyName: 'MobiCom'),
            ),
          ),
        ),
      );
      final foreground = tester
          .widgetList<DecoratedBox>(_in<DecoratedBox>(find.byType(AppCard)))
          .where((d) => d.position == DecorationPosition.foreground);
      expect(foreground, hasLength(1));
      final deco = foreground.single.decoration as BoxDecoration;
      expect(deco.border, isNotNull);
      expect(_in<ClipRRect>(find.byType(AppCard)), findsWidgets);
      expect(tester.getSize(find.byType(AppCard)).width, 300);
    });
  });

  group('AmbientBackground', () {
    testWidgets('isolates child repaints from the gradient paint',
        (tester) async {
      await pumpKit(
        tester,
        const AmbientBackground(child: SizedBox(width: 100, height: 100)),
      );
      final paint = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(AmbientBackground),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      expect(paint.child, isA<RepaintBoundary>());
    });
  });

  group('tinted text meets WCAG AA (4.5:1) on real surfaces', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
    }

    for (final tone in TagTone.values.where((t) => t != TagTone.glass)) {
      testWidgets('TagChip $tone on surface and surfaceElevated',
          (tester) async {
        await pumpKit(tester, TagChip(label: 'Шошго', tone: tone));
        final fg = tester.widget<Text>(find.text('Шошго')).style!.color!;
        final box = tester.widget<Container>(
          _in<Container>(find.byType(TagChip)).first,
        );
        final tint = (box.decoration! as BoxDecoration).color!;
        for (final base in [AppColors.surface, AppColors.surfaceElevated]) {
          expect(
            contrast(fg, Color.alphaBlend(tint, base)),
            greaterThanOrEqualTo(4.5),
            reason: '$tone on $base',
          );
        }
      });
    }

    testWidgets('StatusBanner title/action for every tone', (tester) async {
      for (final tone in BannerTone.values) {
        await pumpKit(
          tester,
          StatusBanner(
            tone: tone,
            title: 'Гарчиг',
            message: 'Мессеж',
            actionLabel: 'Дахин',
            onAction: () {},
          ),
        );
        final panel = Color.alphaBlend(
          StatusBanner.colorFor(tone).withValues(alpha: 0.10),
          AppColors.background,
        );
        for (final label in ['Гарчиг', 'Дахин', 'Мессеж']) {
          final fg = tester.widget<Text>(find.text(label)).style!.color!;
          expect(contrast(fg, panel), greaterThanOrEqualTo(4.5),
              reason: '$tone "$label"');
        }
      }
    });

    testWidgets('danger AppButton label', (tester) async {
      await pumpKit(
        tester,
        AppButton(
          label: 'Устгах',
          variant: AppButtonVariant.danger,
          onPressed: () {},
        ),
      );
      final fg = tester.widget<Text>(find.text('Устгах')).style!.color!;
      for (final base in [AppColors.background, AppColors.surface]) {
        final bg = Color.alphaBlend(
          AppColors.danger.withValues(alpha: 0.12),
          base,
        );
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('AnimatedMoney reduce-motion toggle', () {
    testWidgets('toggling the OS setting never restarts the count from 0',
        (tester) async {
      const money = AnimatedMoney(value: 3400);
      await pumpKit(tester, money);
      await tester.pumpAndSettle();
      expect(find.text('3,400 ₮'), findsOneWidget);

      await pumpKit(tester, money, reduceMotion: true);
      expect(find.text('3,400 ₮'), findsOneWidget);

      await pumpKit(tester, money);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('3,400 ₮'), findsOneWidget);
    });
  });

  group('AnimatedMoney', () {
    testWidgets('negative values and reduce-motion toggling', (tester) async {
      await pumpKit(tester, const AnimatedMoney(value: -2000));
      await tester.pumpAndSettle();
      expect(find.text('-2,000 ₮'), findsOneWidget);
      await pumpKit(
        tester,
        const AnimatedMoney(value: 1234567, withSign: true),
        reduceMotion: true,
      );
      expect(find.text('+1,234,567 ₮'), findsOneWidget);
    });
  });

  testWidgets('kitchen sink at 320pt wide with 2x text: no exceptions',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpKit(
      tester,
      AmbientBackground(
        child: ListView(
          padding: AppLayout.screenInsets,
          children: [
            const SectionHeader(
              title: 'Танд зориулсан видео',
              subtitle: 'Үзээд урамшуулал аваарай',
              trailing: TagChip(label: '12', tone: TagTone.gold),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              onTap: () {},
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CampaignArt(campaignId: 3, companyName: '«Хаан банк»'),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        TagChip(
                          label: '1:30',
                          icon: Icons.schedule_rounded,
                          tone: TagTone.glass,
                        ),
                        RewardChip(amount: 700, glow: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              gradient: AppGradients.gold,
              shadows: AppShadows.goldGlow,
              child: const AnimatedMoney(
                value: 1234567,
                style: AppTextStyles.moneyLarge,
              ),
            ),
            const SizedBox(height: 12),
            const StatusBanner(
              title: 'Алдаа гарлаа',
              message: 'Сүлжээний холболтоо шалгаад дахин оролдоно уу.',
              actionLabel: 'Дахин оролдох',
              onAction: _noop,
            ),
            const SizedBox(height: 12),
            const GroupedCard(
              children: [
                InfoRow(
                  icon: Icons.phone_rounded,
                  label: 'Утасны дугаар',
                  value: '+976 8877 8899',
                ),
                InfoRow(
                  icon: Icons.logout_rounded,
                  label: 'Гарах',
                  danger: true,
                  onTap: _noop,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SegmentedProgress(total: 3, current: 1),
            const SizedBox(height: 12),
            const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'Гүйлгээ алга',
              message: 'Видео үзэж анхны урамшууллаа аваарай.',
            ),
            Row(
              children: [
                const AppIconButton(
                  icon: Icons.close_rounded,
                  semanticLabel: 'Хаах',
                  onPressed: _noop,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(label: 'Үргэлжлүүлэх', onPressed: () {}),
                ),
              ],
            ),
          ],
        ),
      ),
      textScale: 2.0,
      center: false,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
