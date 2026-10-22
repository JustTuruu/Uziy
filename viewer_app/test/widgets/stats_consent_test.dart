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
