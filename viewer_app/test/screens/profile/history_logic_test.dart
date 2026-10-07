import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/view_history_item.dart';
import 'package:viewer_app/screens/profile/history_logic.dart';

ViewHistoryItem _item(double reward) => ViewHistoryItem(
      campaignId: 1,
      title: 't',
      companyName: 'c',
      rewardPaid: reward,
      watchedAt: DateTime(2026, 10, 6),
    );

void main() {
  group('historyTotalReward', () {
    test('sums the rewards', () {
      expect(historyTotalReward([_item(700), _item(500)]), 1200);
    });

    test('is 0 for an empty list', () {
      expect(historyTotalReward([]), 0);
    });
  });

  group('historyDayLabel', () {
    final now = DateTime(2026, 10, 7, 0, 10);

    test('same calendar day is Өнөөдөр', () {
      expect(historyDayLabel(DateTime(2026, 10, 7, 0, 5), now), kToday);
    });

    test('23:50 the day before is Өчигдөр even though under 24 h ago', () {
      expect(historyDayLabel(DateTime(2026, 10, 6, 23, 50), now), kYesterday);
    });

    test('older days use a zero-padded yyyy.MM.dd date', () {
      expect(historyDayLabel(DateTime(2026, 10, 5, 12), now), '2026.10.05');
      expect(historyDayLabel(DateTime(2025, 1, 2), now), '2025.01.02');
    });
  });

  test('historyTimeLabel zero-pads hours and minutes', () {
    expect(historyTimeLabel(DateTime(2026, 10, 7, 9, 5)), '09:05');
    expect(historyTimeLabel(DateTime(2026, 10, 7, 21, 30)), '21:30');
  });
}
