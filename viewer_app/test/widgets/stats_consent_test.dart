import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/statistics_consent.dart';
import 'package:viewer_app/theme/app_theme.dart';
import 'package:viewer_app/widgets/stats_consent.dart';

class _FakeApi implements StatisticsConsentApi {
  _FakeApi(this.status, {this.failDecide = false});
  StatisticsConsentStatus status;
  final bool failDecide;
  final decisions = <bool>[];

  @override
  Future<StatisticsConsent> load() async => StatisticsConsent(status: status);

  @override
  Future<StatisticsConsent> decide({required bool granted}) async {
    if (failDecide) throw Exception('offline');
    decisions.add(granted);
    status = granted
        ? StatisticsConsentStatus.granted
        : StatisticsConsentStatus.declined;
    return StatisticsConsent(status: status);
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('only adults are asked', () {
    expect(canAskStatsConsent(null), isFalse);
    expect(canAskStatsConsent(17), isFalse);
    expect(canAskStatsConsent(18), isTrue);
  });

  test('the explanation says what happens, to whom, and how to undo it', () {
    expect(kStatsConsentBody, contains('нэр, утас'));
    expect(kStatsConsentBody, contains('50'));
    expect(kStatsConsentBody, contains('байгууллагуудад'));
    expect(kStatsConsentBody, contains('цуцална'));
    expect(kStatsConsentBody.toLowerCase(), isNot(contains('админ')));
  });

  group('StatsConsentPrompt', () {
    testWidgets('asks a viewer who never answered and sends yes',
        (tester) async {
      final api = _FakeApi(StatisticsConsentStatus.unasked);
      await _pump(tester, StatsConsentPrompt(api: api));

      expect(find.text(kStatsConsentTitle), findsOneWidget);
      await tester.tap(find.text(kStatsConsentYes));
      await tester.pumpAndSettle();

      expect(api.decisions, [true]);
      expect(find.text(kStatsConsentTitle), findsNothing);
      expect(find.text(kStatsConsentThanks), findsOneWidget);
    });

    testWidgets('a no is respected and the card goes away', (tester) async {
      final api = _FakeApi(StatisticsConsentStatus.unasked);
      await _pump(tester, StatsConsentPrompt(api: api));

      await tester.tap(find.text(kStatsConsentNo));
      await tester.pumpAndSettle();

      expect(api.decisions, [false]);
      expect(find.text(kStatsConsentTitle), findsNothing);
    });

    testWidgets('a viewer who already answered is not asked again',
        (tester) async {
      await _pump(tester,
          StatsConsentPrompt(api: _FakeApi(StatisticsConsentStatus.declined)));
      expect(find.text(kStatsConsentTitle), findsNothing);
    });

    testWidgets('a failed save keeps the question so it can be answered',
        (tester) async {
      final api = _FakeApi(StatisticsConsentStatus.unasked, failDecide: true);
      await _pump(tester, StatsConsentPrompt(api: api));

      await tester.tap(find.text(kStatsConsentYes));
      await tester.pumpAndSettle();

      expect(find.text(kStatsConsentTitle), findsOneWidget);
    });
  });

  group('StatsConsentTile', () {
    testWidgets('shows the current choice and withdraws it with the switch',
        (tester) async {
      final api = _FakeApi(StatisticsConsentStatus.granted);
      await _pump(tester, StatsConsentTile(api: api));

      expect(find.text(kStatsConsentOn), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(api.decisions, [false]);
      expect(find.text(kStatsConsentOff), findsOneWidget);
    });

    testWidgets('a failed save puts the switch back', (tester) async {
      final api = _FakeApi(StatisticsConsentStatus.declined, failDecide: true);
      await _pump(tester, StatsConsentTile(api: api));

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text(kStatsConsentOff), findsOneWidget);
    });
  });
}
