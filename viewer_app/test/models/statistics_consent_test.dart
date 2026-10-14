import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/statistics_consent.dart';

void main() {
  test('reads the backend answer', () {
    final c = StatisticsConsent.fromJson({
      'status': 'GRANTED',
      'decidedAt': '2026-10-14T04:00:00Z',
      'version': '2026-10-14',
    });
    expect(c.status, StatisticsConsentStatus.granted);
    expect(c.granted, isTrue);
    expect(c.decidedAt, DateTime.utc(2026, 10, 14, 4).toLocal());
  });

  test('never asked, or anything unknown, never reads as yes', () {
    expect(StatisticsConsent.fromJson({'status': 'UNASKED'}).granted, isFalse);
    expect(StatisticsConsentStatus.fromWire('MAYBE'),
        StatisticsConsentStatus.unasked);
    expect(StatisticsConsentStatus.fromWire(null),
        StatisticsConsentStatus.unasked);
    expect(StatisticsConsentStatus.fromWire('DECLINED'),
        StatisticsConsentStatus.declined);
  });
}
