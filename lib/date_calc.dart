/// 次の支払日までの日数を数える。
/// 月末を超える日付(毎月31日の30日までの月、2/29の平年など)は、その月の最終日として扱う。
/// 日付の差は UTC の暦日で数えるので、時刻や夏時間のあるタイムゾーンでも日数がずれない。

DateTime _clampedDate(int year, int month, int day) {
  final first = DateTime.utc(year, month, 1); // monthが13でも翌年に正しく繰り上がる
  final lastDay = DateTime.utc(first.year, first.month + 1, 0).day;
  return DateTime.utc(first.year, first.month, day > lastDay ? lastDay : day);
}

/// [now] の日付から、次の支払日まで何日か(今日なら0)。
int daysUntilNext(DateTime now, int? month, int day, bool isYearly) {
  final today = DateTime.utc(now.year, now.month, now.day);
  DateTime next;
  if (isYearly && month != null) {
    next = _clampedDate(now.year, month, day);
    if (next.isBefore(today)) next = _clampedDate(now.year + 1, month, day);
  } else {
    next = _clampedDate(now.year, now.month, day);
    if (next.isBefore(today)) next = _clampedDate(now.year, now.month + 1, day);
  }
  return next.difference(today).inDays;
}
