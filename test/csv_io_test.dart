import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/csv_io.dart';

void main() {
  final subs = <Map<String, dynamic>>[
    {'name': 'Netflix, プレミアム', 'price': 1490, 'month': 1, 'day': 15, 'genre': '動画', 'isYearly': false, 'includeInMonthly': true, 'isReviewing': true, 'usage': 'often', 'showInMonthly': false, 'memo': '家族と共有, 解約は月末'},
    {'name': 'He said "hi"', 'price': 72336, 'month': 11, 'day': 5, 'genre': 'AI', 'isYearly': true, 'includeInMonthly': false, 'isReviewing': false, 'usage': 'rarely', 'showInMonthly': true},
    {'name': '改行\nあり', 'price': 980, 'month': 1, 'day': 3, 'genre': '音楽', 'isYearly': false},
  ];

  test('書き出して読み込むと、同じ内容に戻る', () {
    final r = parseCsv(buildCsv(subs, {'動画': 0xFF8E2DE2, 'AI': 0xFFFF2D95}));
    expect(r.errors, isEmpty);
    expect(r.items.length, 3);

    final a = r.items[0], b = r.items[1], c = r.items[2];
    expect(a['name'], 'Netflix, プレミアム');
    expect(a['price'], 1490);
    expect(a['isYearly'], false);
    expect(a['day'], 15);
    expect(a['isReviewing'], true);
    expect(a['usage'], 'often');
    expect(a['memo'], '家族と共有, 解約は月末');

    expect(b['name'], 'He said "hi"');
    expect(b['isYearly'], true);
    expect(b['month'], 11);
    expect(b['includeInMonthly'], false);
    expect(b['usage'], 'rarely');
    expect(b['showInMonthly'], true);
    expect(b['memo'], isNull);

    expect(c['name'], '改行\nあり');
    expect(c['usage'], isNull);

    expect(r.genreColors, {'動画': 0xFF8E2DE2, 'AI': 0xFFFF2D95});
  });

  test('古い形式(8列・BOM・CRLF)も読める', () {
    final r = parseCsv('﻿名前,金額,サイクル,更新月,更新日,ジャンル,計上,検討中\r\nSpotify,980,月,,3,音楽,込,\r\nPrime,5900,年,3,10,クレカ,外,検討中\r\n');
    expect(r.errors, isEmpty);
    expect(r.items.length, 2);
    expect(r.items[0]['isYearly'], false);
    expect(r.items[1]['isYearly'], true);
    expect(r.items[1]['month'], 3);
    expect(r.items[1]['includeInMonthly'], false);
    expect(r.items[1]['isReviewing'], true);
  });

  test('列の順番が違っても、列名で対応づける', () {
    final r = parseCsv('金額,名前,ジャンル\n500,Hulu,動画\n');
    expect(r.items.single['name'], 'Hulu');
    expect(r.items.single['price'], 500);
    expect(r.items.single['genre'], '動画');
    expect(r.items.single['day'], 1);
  });

  test('読めない行は理由つきで飛ばし、読める行は残す', () {
    final r = parseCsv('名前,金額\nA,abc\n,100\nC,"1,200円"\n');
    expect(r.items.map((e) => '${e['name']}:${e['price']}'), ['C:1200']);
    expect(r.errors.length, 2);
  });

  test('このアプリのCSVでなければ、何も読み込まない', () {
    expect(parseCsv('foo,bar\n1,2\n').items, isEmpty);
    expect(parseCsv('foo,bar\n1,2\n').errors, isNotEmpty);
    expect(parseCsv('').items, isEmpty);
  });
}
