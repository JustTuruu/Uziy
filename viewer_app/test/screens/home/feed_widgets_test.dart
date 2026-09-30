import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/campaign.dart';
import 'package:viewer_app/screens/home/feed_logic.dart';
import 'package:viewer_app/screens/home/feed_widgets.dart';
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

void main() {
  group('CampaignCard', () {
    testWidgets('renders title, company, reward, duration and CTA',
        (tester) async {
      await _pump(tester, CampaignCard(campaign: _video, onTap: () {}));
      await tester.pumpAndSettle();

      expect(find.text(_video.title), findsOneWidget);
      expect(find.text('MobiCom'), findsOneWidget);
      expect(find.text('+700 ₮'), findsOneWidget);
      expect(find.text('45 сек'), findsOneWidget);
      expect(find.text('Үзэх'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byType(CampaignArt), findsOneWidget);
    });

    testWidgets('survey-only shows the Судалгаа tag and Бөглөх CTA',
        (tester) async {
      await _pump(tester, CampaignCard(campaign: _survey, onTap: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Судалгаа'), findsOneWidget);
      expect(find.text('Бөглөх'), findsOneWidget);
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
        title: 'Маш урт гарчигтай кампанит ажил, хоёр мөрөөс хэтэрвэл '
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

    testWidgets('renders under reduce-motion', (tester) async {
      await _pump(
        tester,
        CampaignCard(campaign: _video, onTap: () {}),
        reduceMotion: true,
      );
      await tester.pump();
      expect(find.text(_video.title), findsOneWidget);
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
    testWidgets('shows the three tabs and reports a new selection',
        (tester) async {
      final changes = <FeedFilter>[];
      await _pump(
        tester,
        FeedFilterBar(value: FeedFilter.all, onChanged: changes.add),
      );

      expect(find.text('Бүгд'), findsOneWidget);
      expect(find.text('Видео'), findsOneWidget);
      expect(find.text('Судалгаа'), findsOneWidget);

      await tester.tap(find.text('Видео'));
      await tester.tap(find.text('Судалгаа'));
      await tester.pumpAndSettle();
      expect(changes, [FeedFilter.video, FeedFilter.survey]);
    });

    testWidgets('tapping the selected tab does nothing', (tester) async {
      final changes = <FeedFilter>[];
      await _pump(
        tester,
        FeedFilterBar(value: FeedFilter.video, onChanged: changes.add),
      );
      await tester.tap(find.text('Видео'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
    });

    testWidgets('segments are full-height tap targets with selected state',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        FeedFilterBar(value: FeedFilter.survey, onChanged: (_) {}),
      );
      expect(
        tester.getSize(find.byType(Pressable).first).height,
        greaterThanOrEqualTo(AppLayout.minTapTarget),
      );
      expect(
        tester.getSemantics(find.text('Судалгаа')),
        isSemantics(label: 'Судалгаа', isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.text('Бүгд')),
        isSemantics(label: 'Бүгд', isSelected: false),
      );
      handle.dispose();
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

    testWidgets('header greets by time of day and shows the title',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        FeedHeader(
          now: DateTime(2026, 9, 28, 8),
          balance: 700,
          onBalanceTap: () => taps++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Өглөөний мэнд'), findsOneWidget);
      expect(find.text(FeedHeader.title), findsOneWidget);
      expect(find.text('700 ₮'), findsOneWidget);

      await tester.tap(find.byType(BalancePill));
      expect(taps, 1);
    });

    testWidgets('header fits a 320pt phone at 1.3x text', (tester) async {
      _useSmallPhone(tester);
      await _pump(
        tester,
        FeedHeader(
          now: DateTime(2026, 9, 28, 20),
          balance: 1234567,
          onBalanceTap: () {},
        ),
        textScale: 1.3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Оройн мэнд'), findsOneWidget);
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
