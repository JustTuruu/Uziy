import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/statistics_consent.dart';
import 'package:viewer_app/screens/profile/privacy_content.dart';
import 'package:viewer_app/screens/profile/privacy_screen.dart';
import 'package:viewer_app/widgets/stats_consent.dart';
import 'package:viewer_app/widgets/ui.dart';

class _FakeStatsApi implements StatisticsConsentApi {
  StatisticsConsentStatus status = StatisticsConsentStatus.granted;
  final decisions = <bool>[];

  @override
  Future<StatisticsConsent> load() async => StatisticsConsent(status: status);

  @override
  Future<StatisticsConsent> decide({required bool granted}) async {
    decisions.add(granted);
    status = granted
        ? StatisticsConsentStatus.granted
        : StatisticsConsentStatus.declined;
    return StatisticsConsent(status: status);
  }
}

Future<_FakeStatsApi> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 3000) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final api = _FakeStatsApi();
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: PrivacyScreen(statsApi: api)),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('shows the title, the intro and the sections', (tester) async {
    await _pump(tester);

    expect(find.text(kPrivacyTitle), findsOneWidget);
    expect(find.byType(PrivacyIntroCard), findsOneWidget);
    expect(find.text(kPrivacyIntroTitle), findsOneWidget);
    expect(find.text(kPrivacyIntro), findsOneWidget);
    expect(
        find.byType(PolicySectionView), findsNWidgets(kPrivacySections.length));
    for (final section in kPrivacySections) {
      expect(find.text(section.heading), findsOneWidget);
      expect(find.text(section.body), findsOneWidget);
    }
  });

  testWidgets('the statistics switch sits right under its section',
      (tester) async {
    await _pump(tester);

    expect(find.byType(StatsConsentTile), findsOneWidget);
    final switchTop = tester.getTopLeft(find.byType(StatsConsentTile)).dy;
    final sectionTop = tester.getTopLeft(find.text(kStatsSectionHeading)).dy;
    final sections = kPrivacySections.map((s) => s.heading).toList();
    final next = sections[sections.indexOf(kStatsSectionHeading) + 1];
    expect(switchTop, greaterThan(sectionTop));
    expect(switchTop, lessThan(tester.getTopLeft(find.text(next)).dy));
  });

  testWidgets('the consent can be withdrawn here', (tester) async {
    final api = await _pump(tester);
    await tester.ensureVisible(find.byType(StatsConsentTile));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(api.decisions, [false]);
    expect(find.text(kStatsConsentOff), findsOneWidget);
  });

  test('every policy section has a heading and a body', () {
    for (final section in kPrivacySections) {
      expect(section.heading.trim(), isNotEmpty);
      expect(section.body.trim(), isNotEmpty);
    }
  });

  test('the copy points to where the switch now is', () {
    expect(kStatsConsentBody, contains('Нууцлалын бодлого'));
    expect(kStatsConsentThanks, contains('Нууцлалын бодлого'));
    final rights = kPrivacySections.map((s) => s.body).join(' ');
    expect(rights, isNot(contains('зөвшөөрлөө Профайл хэсгээс')));
  });
}
