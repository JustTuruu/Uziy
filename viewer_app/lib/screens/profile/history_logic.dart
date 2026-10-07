/// Pure helpers for the watch-history page. No Flutter widgets, so they are
/// unit-testable in isolation.
library;

import '../../models/view_history_item.dart';

const String kHistoryTitle = 'Үзсэн видеонуудын түүх';
const String kHistoryLoadError = 'Түүх ачаалж чадсангүй';
const String kHistoryEmptyTitle = 'Түүх хоосон байна';
const String kHistoryEmptyMessage =
    'Видео үзээд судалгаа бөглөх бүртээ энд бүртгэгдэнэ.';
const String kToday = 'Өнөөдөр';
const String kYesterday = 'Өчигдөр';

/// Total reward of [items], in tögrög.
double historyTotalReward(List<ViewHistoryItem> items) =>
    items.fold(0.0, (sum, item) => sum + item.rewardPaid);

/// 'Өнөөдөр' / 'Өчигдөр' for the two latest calendar days, otherwise
/// 'yyyy.MM.dd'. Compares calendar days in [watched]'s own zone, not 24 h
/// spans, so a view at 23:50 is "yesterday" at 00:10.
String historyDayLabel(DateTime watched, DateTime now) {
  final day = DateTime(watched.year, watched.month, watched.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return kToday;
  if (diff == 1) return kYesterday;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${watched.year}.${two(watched.month)}.${two(watched.day)}';
}

/// 'HH:mm' of [time].
String historyTimeLabel(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}';
}
