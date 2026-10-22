import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/campaign.dart';
import 'package:viewer_app/screens/home/feed_logic.dart';
import 'package:viewer_app/screens/home/feed_widgets.dart';
import 'package:viewer_app/widgets/appearance_settings.dart';
import 'package:viewer_app/widgets/ui.dart';

const _video = Campaign(
  id: 1,
  companyName: 'MobiCom',
  videoUrl: '',
  title: 'Шинэ 5G багц - Танд хамгийн тохирсон',
  durationSeconds: 45,
  rewardPerUser: 700,
);

const _survey = Campaign(
  id: 3,
  companyName: 'UniTel',
  videoUrl: '',
  title: 'Судалгаа: Дуртай интернэт үйлчилгээ',
  durationSeconds: 0,
  rewardPerUser: 250,
  hasVideo: false,
);

/// Pumps [child] in the real theme, scrollable, with 20pt gutters.
/// [reduceMotion] emulates the OS setting; [textScale] the OS text size.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
  double textScale = 1.0,
  bool dark = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  );
}

/// iPhone SE width (320pt).
void _useSmallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void _noFilter(FeedFilter _) {}

void main() {
  group('CampaignCard', () {
    testWidgets('renders title, company, reward and duration; no CTA button',
        (tester) async {
      await _pump(tester, CampaignCard(campaign: _video, onTap: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Шинэ 5G багц'), findsOneWidget);
      expect(find.text('Танд хамгийн тохирсон'), findsOneWidget);
      expect(find.text('MobiCom'), findsOneWidget);
      expect(find.text('+700 ₮'), findsOneWidget);
      expect(find.text('45 сек'), findsOneWidget);
      // Owner, 2026-10-21: the card itself is the button.
      expect(find.text('Үзэх'), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byType(CampaignArt), findsOneWidget);
    });

    testWidgets('survey-only shows the Судалгаа tag and no Бөглөх button',
        (tester) async {
      await _pump(tester, CampaignCard(campaign: _survey, onTap: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Судалгаа'), findsOneWidget);
      expect(find.text('Бөглөх'), findsNothing);
      expect(find.text('+250 ₮'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.text('0 сек'), findsNothing);
    });

    testWidgets('tap fires onTap once', (tester) async {
      var taps = 0;
      await _pump(tester, CampaignCard(campaign: _video, onTap: () => taps++));
      await tester.tap(find.byType(CampaignCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('is one button with a single spoken sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, CampaignCard(campaign: _video, onTap: () {}));
      await tester.pumpAndSettle();

      final label = campaignSemanticLabel(_video);
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('no overflow on a 320pt phone at 1.3x text', (tester) async {
      _useSmallPhone(tester);
      const long = Campaign(
        id: 9,
        companyName: 'Монголын Үндэсний Худалдаа Аж Үйлдвэрийн Танхим',
        videoUrl: '',
        title: 'Маш урт гарчигтай судалгаа, хоёр мөрөөс хэтэрвэл '
            'гурван цэгээр таслагдах ёстой бөгөөд хэзээ ч халихгүй',
        durationSeconds: 125,
        rewardPerUser: 12500,
      );
      await _pump(
        tester,
        CampaignCard(campaign: long, onTap: () {}),
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('2:05'), findsOneWidget);
      expect(find.text('+12,500 ₮'), findsOneWidget);
    });

    testWidgets('dark card keeps the reward readable at 2x text',
        (tester) async {
      _useSmallPhone(tester);
      await _pump(tester, CampaignCard(campaign: _video, onTap: () {}),
          textScale: 2, dark: true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('+700 ₮'), findsOneWidget);
    });

    testWidgets('the reward sits on the publisher line, right of the name',
        (tester) async {
      await _pump(tester, CampaignCard(campaign: _video, onTap: () {}));
      await tester.pumpAndSettle();
      final company = tester.getRect(find.text('MobiCom'));
      final reward = tester.getRect(find.byType(RewardChip));
      expect(reward.center.dy, closeTo(company.center.dy, 2));
      expect(reward.left, greaterThan(company.right - 1));
      expect(
        reward.right,
        closeTo(
            tester.getRect(find.byType(CardTitle)).left +
                tester.getRect(find.byType(CampaignCard)).width -
                32,
            1),
        reason: 'flush with the card padding on the right',
      );
    });

    testWidgets('renders under reduce-motion', (tester) async {
      await _pump(
        tester,
        CampaignCard(campaign: _video, onTap: () {}),
        reduceMotion: true,
      );
      await tester.pump();
      expect(find.text('Шинэ 5G багц'), findsOneWidget);
    });
  });

  test('CampaignCard.stacksReward: one line when roomy, stacked when tight',
      () {
    expect(CampaignCard.stacksReward(320, 1.0), isFalse);
    expect(CampaignCard.stacksReward(248, 1.3), isTrue);
    expect(CampaignCard.stacksReward(400, 2.0), isTrue);
  });

  group('CardTitle', () {
    testWidgets('shows the headline big and the tagline lighter beneath it',
        (tester) async {
      await _pump(tester, const CardTitle(title: 'Шинэ 5G багц - Танд'));
      await tester.pumpAndSettle();

      final headline = tester.widget<Text>(find.text('Шинэ 5G багц'));
      final tagline = tester.widget<Text>(find.text('Танд'));
      expect(headline.style, CardTitle.headlineStyle);
      expect(tagline.style, CardTitle.taglineStyle);
      expect(
        tester.getTopLeft(find.text('Танд')).dy,
        greaterThan(tester.getBottomLeft(find.text('Шинэ 5G багц')).dy - 1),
      );
    });

    testWidgets('a title without a separator is only the headline',
        (tester) async {
      await _pump(tester, const CardTitle(title: 'Зуны хямдрал'));
      await tester.pumpAndSettle();

      expect(find.byType(Text), findsOneWidget);
      expect(find.text('Зуны хямдрал'), findsOneWidget);
    });
  });

  group('EarningsHeroCard', () {
    testWidgets('counts up to the feed total with the kind caption',
        (tester) async {
      await _pump(
        tester,
        EarningsHeroCard(summary: summarizeFeed(Campaign.mockFeed())),
      );
      await tester.pumpAndSettle();

      expect(find.text(EarningsHeroCard.label), findsOneWidget);
      expect(find.text('1,450 ₮'), findsOneWidget);
      expect(find.text('2 видео · 1 судалгаа'), findsOneWidget);
      expect(find.byType(CoinIcon), findsNWidgets(2));
    });

    testWidgets('reduce-motion shows the final total on the first frame',
        (tester) async {
      await _pump(
        tester,
        EarningsHeroCard(summary: summarizeFeed(const [_video])),
        reduceMotion: true,
      );
      expect(find.text('700 ₮'), findsOneWidget);
      expect(find.text('1 видео'), findsOneWidget);
    });

    test('coin stack only when the text column keeps its room', () {
      expect(EarningsHeroCard.showsCoins(280, 1.0), isTrue); // SE card
      expect(EarningsHeroCard.showsCoins(280, 1.3), isFalse);
      expect(EarningsHeroCard.showsCoins(350, 1.3), isTrue); // 390pt phone
      expect(EarningsHeroCard.showsCoins(240, 1.0), isFalse);
    });

    testWidgets('drops the coin stack on a narrow card, no overflow',
        (tester) async {
      _useSmallPhone(tester);
      await _pump(
        tester,
        const SizedBox(
          width: 240,
          child: EarningsHeroCard(
            summary: FeedSummary(
              totalReward: 1234567,
              videoCount: 12,
              surveyCount: 7,
            ),
          ),
        ),
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(CoinIcon), findsNothing);
      expect(find.text('1,234,567 ₮'), findsOneWidget);
    });
  });

  group('FeedFilterBar', () {
    testWidgets('three chips with icon and name; reports a change',
        (tester) async {
      final changes = <FeedFilter>[];
      await _pump(
        tester,
        FeedFilterBar(value: FeedFilter.all, onChanged: changes.add),
      );

      expect(find.byType(FeedFilterChip), findsNWidgets(3));
      expect(find.text('Бүгд'), findsOneWidget);
      expect(find.byIcon(AppIcons.feedAll), findsOneWidget);
      expect(find.byIcon(AppIcons.feedVideo), findsOneWidget);
      expect(find.byIcon(AppIcons.feedSurvey), findsOneWidget);

      await tester.tap(find.text('Видео'));
      await tester.tap(find.text('Судалгаа'));
      await tester.pumpAndSettle();
      expect(changes, [FeedFilter.video, FeedFilter.survey]);
    });

    testWidgets('tapping the selected chip does nothing', (tester) async {
      final changes = <FeedFilter>[];
      await _pump(
        tester,
        FeedFilterBar(value: FeedFilter.video, onChanged: changes.add),
      );
      await tester.tap(find.text('Видео'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
    });

    testWidgets('the selected chip is a flat action fill, the rest are quiet',
        (tester) async {
      await _pump(
        tester,
        FeedFilterBar(value: FeedFilter.survey, onChanged: (_) {}),
      );
      await tester.pumpAndSettle();
      BoxDecoration deco(String label) => tester
          .widget<AnimatedContainer>(find.descendant(
            of: find.widgetWithText(FeedFilterChip, label),
            matching: find.byType(AnimatedContainer),
          ))
          .decoration! as BoxDecoration;
      expect(deco('Судалгаа').color, AppColors.primary);
      expect(deco('Судалгаа').gradient, isNull);
      expect(deco('Бүгд').color, AppColors.surface);
    });

    testWidgets('chips are 44pt targets and announce name and state',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        FeedFilterBar(value: FeedFilter.survey, onChanged: (_) {}),
      );
      expect(
        tester.getSize(find.byType(FeedFilterChip).first).height,
        greaterThanOrEqualTo(AppLayout.minTapTarget),
      );
      expect(
        tester.getSemantics(find.widgetWithText(FeedFilterChip, 'Судалгаа')),
        isSemantics(label: 'Судалгаа', isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.widgetWithText(FeedFilterChip, 'Бүгд')),
        isSemantics(label: 'Бүгд', isSelected: false),
      );
      handle.dispose();
    });

    // The counts already sit in the hero card above; repeating them made
    // the third chip run off a 390pt screen (checked with the real font in
    // tool/render_design_test.dart).
    testWidgets('chips carry no count badge', (tester) async {
      await _pump(
        tester,
        FeedFilterBar(value: FeedFilter.all, onChanged: (_) {}),
      );
      await tester.pumpAndSettle();
      final texts = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(FeedFilterChip), matching: find.byType(Text)))
          .map((t) => t.data)
          .toList();
      expect(texts, ['Бүгд', 'Видео', 'Судалгаа']);
    });

    testWidgets('every chip label keeps the same size (no shrink-to-fit)',
        (tester) async {
      await _pump(
        tester,
        FeedFilterBar(value: FeedFilter.all, onChanged: (_) {}),
      );
      await tester.pumpAndSettle();
      final heights = [
        for (final l in ['Бүгд', 'Видео', 'Судалгаа'])
          tester.getSize(find.text(l)).height,
      ];
      expect(heights.toSet(), hasLength(1));
      expect(find.byType(FittedBox), findsNothing);
    });

    testWidgets('fits a 320pt phone at 1.3x text', (tester) async {
      _useSmallPhone(tester);
      await _pump(
        tester,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: FeedFilterBar(
            value: FeedFilter.all,
            onChanged: _noFilter,
          ),
        ),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('EarningsHeroCard', () {
    test('light: a flat forest sheet with white ink', () {
      final look = EarningsHeroCard.lookIn(const AppPalette(false));
      expect(look.fill, AppColors.primary);
      expect(look.money, AppColors.onPrimary);
    });

    test('dark: the graphite surface with sage money, not a sage block', () {
      const dark = AppPalette(true);
      final look = EarningsHeroCard.lookIn(dark);
      expect(look.fill, dark.surfaceElevated);
      expect(look.fill, isNot(dark.primary));
      expect(look.money, dark.primary);
    });

    testWidgets('draws flat in both themes', (tester) async {
      for (final dark in [false, true]) {
        await _pump(
          tester,
          const EarningsHeroCard(
            summary:
                FeedSummary(totalReward: 1450, videoCount: 2, surveyCount: 1),
          ),
          dark: dark,
        );
        await tester.pumpAndSettle();
        final card = tester.widget<AppCard>(find.byType(AppCard));
        expect(card.gradient, isNull, reason: 'dark: $dark');
      }
    });
  });

  group('BalancePill / FeedHeader', () {
    testWidgets('pill shows the balance and fires onTap', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        Row(
          children: [BalancePill(balance: 3400, onTap: () => taps++)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3,400 ₮'), findsOneWidget);

      await tester.tap(find.byType(BalancePill));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('pill shows a placeholder while the balance is unknown',
        (tester) async {
      await _pump(
        tester,
        Row(children: [BalancePill(balance: null, onTap: () {})]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedMoney), findsNothing);
      expect(find.byKey(const ValueKey('balance-placeholder')), findsOneWidget);
    });

    testWidgets('guest header shows a sign-in pill instead of the balance',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        FeedHeader(
          balance: null,
          guest: true,
          onBalanceTap: () => taps++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BalancePill), findsNothing);
      expect(find.text(GuestSignInPill.label), findsOneWidget);
      await tester.tap(find.byType(GuestSignInPill));
      expect(taps, 1);
    });

    testWidgets('header: one top row and the title, no greeting',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        FeedHeader(
          balance: 700,
          onBalanceTap: () => taps++,
        ),
      );
      await tester.pumpAndSettle();
      // Owner, 2026-10-21: no 'Өглөөний / Өдрийн / Оройн мэнд' line.
      expect(find.textContaining('мэнд'), findsNothing);
      expect(find.text('Сайн байна уу'), findsNothing);
      expect(find.text('Видео & судалгаа'), findsOneWidget);
      // Wordmark, balance and the appearance button share the top row.
      final top = tester.getCenter(find.byType(UziyWordmark)).dy;
      expect(tester.getCenter(find.byType(BalancePill)).dy, closeTo(top, 1));
      expect(
          tester.getCenter(find.byType(ThemeModeButton)).dy, closeTo(top, 1));
      expect(
        tester.getTopRight(find.byType(BalancePill)).dx,
        lessThan(tester.getTopLeft(find.byType(ThemeModeButton)).dx),
      );
      expect(
        tester.widget<Text>(find.text('Видео & судалгаа')).style?.fontSize,
        AppTextStyles.pageTitle.fontSize,
        reason: 'the home title uses the smaller tab-title size',
      );
      expect(find.text('Үзэж, хариулж, урамшуулал аваарай'), findsNothing,
          reason: 'the explainer under the title was removed');
      expect(find.text('700 ₮'), findsOneWidget);
      expect(find.byType(UziyWordmark), findsOneWidget);
      expect(find.byType(ThemeModeButton), findsOneWidget);
      expect(find.byType(TagChip), findsNothing,
          reason: 'the tagline chip was removed from the header');

      await tester.tap(find.byType(BalancePill));
      expect(taps, 1);
    });

    testWidgets('header fits a 320pt phone at 1.3x text', (tester) async {
      _useSmallPhone(tester);
      await _pump(
        tester,
        FeedHeader(
          balance: 1234567,
          onBalanceTap: () {},
        ),
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BalancePill), findsOneWidget);
    });
  });

  group('FeedSkeleton', () {
    testWidgets('mirrors the feed layout and announces loading',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const FeedSkeleton(), reduceMotion: true);
      await tester.pump();
      expect(find.byType(CampaignCardSkeleton), findsNWidgets(2));
      expect(find.bySemanticsLabel('Ачаалж байна'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('shimmer animates without errors', (tester) async {
      await _pump(tester, const FeedSkeleton(cardCount: 1));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(CampaignCardSkeleton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
