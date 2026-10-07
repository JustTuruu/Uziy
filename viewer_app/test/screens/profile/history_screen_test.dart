import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/view_history_item.dart';
import 'package:viewer_app/screens/profile/history_logic.dart';
import 'package:viewer_app/screens/profile/history_screen.dart';
import 'package:viewer_app/widgets/ui.dart';

final _now = DateTime(2026, 10, 7, 12);

ViewHistoryItem _item(String title, {double reward = 700, int daysAgo = 0}) =>
    ViewHistoryItem(
      campaignId: title.hashCode,
      title: title,
      companyName: 'MobiCom',
      rewardPaid: reward,
      watchedAt: DateTime(2026, 10, 7 - daysAgo, 9, 5),
    );

Future<void> _pump(
  WidgetTester tester, {
  List<ViewHistoryItem>? items,
  String? error,
  VoidCallback? onRetry,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: HistoryBody(
            items: items,
            error: error,
            onRetry: onRetry ?? () {},
            now: _now,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('HistoryBody', () {
    testWidgets('shows the skeleton while loading', (tester) async {
      await _pump(tester);

      expect(find.byType(Skeleton), findsWidgets);
      expect(find.byType(StatusBanner), findsNothing);
    });

    testWidgets('shows the error with a working retry', (tester) async {
      var retries = 0;
      await _pump(tester, error: kHistoryLoadError, onRetry: () => retries++);

      expect(find.text(kHistoryLoadError), findsOneWidget);
      await tester.tap(find.text('Дахин оролдох'));
      expect(retries, 1);
    });

    testWidgets('shows the empty state for no views', (tester) async {
      await _pump(tester, items: const []);

      expect(find.text(kHistoryEmptyTitle), findsOneWidget);
      expect(find.byType(HistoryRow), findsNothing);
    });

    testWidgets('lists every view and totals the rewards', (tester) async {
      await _pump(
        tester,
        items: [_item('A'), _item('B', reward: 500, daysAgo: 1)],
      );

      expect(find.byType(HistoryRow), findsNWidgets(2));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1,200 ₮'), findsOneWidget);
    });

    testWidgets('a row shows company, day, time and the signed reward',
        (tester) async {
      await _pump(tester, items: [_item('A', daysAgo: 1)]);

      expect(find.text('MobiCom · $kYesterday · 09:05'), findsOneWidget);
      expect(find.text('+700 ₮'), findsOneWidget);
    });

    testWidgets('a row without a company name omits the separator',
        (tester) async {
      final item = ViewHistoryItem(
        campaignId: 1,
        title: 'A',
        companyName: '',
        rewardPaid: 700,
        watchedAt: DateTime(2026, 10, 7, 9, 5),
      );
      await _pump(tester, items: [item]);

      expect(find.text('$kToday · 09:05'), findsOneWidget);
    });
  });
}
