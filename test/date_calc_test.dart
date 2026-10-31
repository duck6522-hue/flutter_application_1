import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/date_calc.dart';

void main() {
  group('毎月の支払い', () {
    test('今日が支払日なら0日', () {
      expect(daysUntilNext(DateTime(2026, 11, 1), null, 1, false), 0);
      expect(daysUntilNext(DateTime(2026, 11, 30), null, 30, false), 0);
    });
    test('日付が過ぎていたら来月', () {
      expect(daysUntilNext(DateTime(2026, 11, 20), null, 15, false), 25); // 12/15
    });
    test('12月から1月へ繰り上がる', () {
      expect(daysUntilNext(DateTime(2026, 12, 20), null, 15, false), 26); // 1/15
    });
    test('31日は、30日までの月では月末(30日)になる', () {
      expect(daysUntilNext(DateTime(2026, 11, 1), null, 31, false), 29); // 11/30
      expect(daysUntilNext(DateTime(2026, 11, 15), null, 31, false), 15);
      expect(daysUntilNext(DateTime(2026, 12, 1), null, 31, false), 30); // 12/31
    });
    test('30日・31日は、2月では月末(28日/うるう年は29日)になる', () {
      expect(daysUntilNext(DateTime(2027, 2, 15), null, 30, false), 13); // 2/28
      expect(daysUntilNext(DateTime(2028, 2, 15), null, 30, false), 14); // 2/29
      expect(daysUntilNext(DateTime(2027, 2, 10), null, 29, false), 18); // 平年: 2/28
      expect(daysUntilNext(DateTime(2028, 2, 10), null, 29, false), 19); // うるう年: 2/29
    });
    test('月末を過ぎたら翌月の月末に進む', () {
      expect(daysUntilNext(DateTime(2027, 2, 1), null, 31, false), 27); // 2/28
      expect(daysUntilNext(DateTime(2027, 1, 31), null, 31, false), 0);
    });
  });

  group('毎年の支払い', () {
    test('今年まだなら今年', () {
      expect(daysUntilNext(DateTime(2026, 10, 30), 11, 5, true), 6);
    });
    test('今年過ぎていたら来年', () {
      expect(daysUntilNext(DateTime(2026, 10, 30), 4, 7, true), 159); // 2027/4/7
    });
    test('年末から年始へ', () {
      expect(daysUntilNext(DateTime(2026, 12, 31), 12, 31, true), 0);
      expect(daysUntilNext(DateTime(2026, 12, 31), 1, 1, true), 1);
    });
    test('2/29は、平年では2/28になる', () {
      expect(daysUntilNext(DateTime(2026, 3, 1), 2, 29, true), 364); // 2027/2/28
      expect(daysUntilNext(DateTime(2028, 1, 1), 2, 29, true), 59); // 2028/2/29
      expect(daysUntilNext(DateTime(2027, 2, 1), 2, 29, true), 27); // 2027/2/28
    });
  });

  test('時刻が入っていても、日数は暦日で数える', () {
    expect(daysUntilNext(DateTime(2026, 11, 1, 23, 59), null, 2, false), 1);
    expect(daysUntilNext(DateTime(2026, 11, 1, 0, 1), null, 2, false), 1);
  });
}
