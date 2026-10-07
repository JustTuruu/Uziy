import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/view_history_item.dart';

void main() {
  group('ViewHistoryItem.fromJson', () {
    test('parses every field the backend sends', () {
      final item = ViewHistoryItem.fromJson({
        'campaignId': 3,
        'title': 'Шинэ 5G багц',
        'companyName': 'MobiCom',
        'rewardPaid': 700,
        'watchedAt': '2026-10-06T10:00:00+08:00',
      });

      expect(item.campaignId, 3);
      expect(item.title, 'Шинэ 5G багц');
      expect(item.companyName, 'MobiCom');
      expect(item.rewardPaid, 700.0);
      expect(
        item.watchedAt.toUtc(),
        DateTime.utc(2026, 10, 6, 2),
      );
    });

    test('missing title and company fall back to empty strings', () {
      final item = ViewHistoryItem.fromJson({
        'campaignId': 3,
        'rewardPaid': 500.5,
        'watchedAt': '2026-10-06T02:00:00Z',
      });

      expect(item.title, '');
      expect(item.companyName, '');
      expect(item.rewardPaid, 500.5);
    });
  });
}
