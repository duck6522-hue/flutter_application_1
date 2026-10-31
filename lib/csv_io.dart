/// 引き継ぎ用のCSVの書き出しと読み込み。
/// 読み込みは列の名前で対応づけるので、列の順番が違っていたり、古い形式(列が少ない)でも読める。

const List<String> csvHeaders = ['名前', '金額', 'サイクル', '更新月', '更新日', 'ジャンル', '計上', '検討中', '利用頻度', '月額にも含む', 'ジャンル色'];

const _usageToLabel = {'often': 'よく使う', 'sometimes': 'たまに', 'rarely': 'ほぼ使わない'};
const _labelToUsage = {'よく使う': 'often', 'たまに': 'sometimes', 'たまに使う': 'sometimes', 'ほぼ使わない': 'rarely'};

class CsvImport {
  final List<Map<String, dynamic>> items; // 読み込めた明細
  final Map<String, int> genreColors; // CSVに入っていたジャンルの色
  final List<String> errors; // 読み込めなかった行の理由
  const CsvImport(this.items, this.genreColors, this.errors);
}

String _escape(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

/// 全データをCSV文字列にする(Excelで文字化けしないようBOMつき)
String buildCsv(List<Map<String, dynamic>> subs, Map<String, int> genreColors) {
  final b = StringBuffer('﻿')..writeln(csvHeaders.join(','));
  for (final s in subs) {
    final yearly = s['isYearly'] ?? false;
    final color = genreColors[s['genre']];
    b.writeln([
      _escape('${s['name']}'),
      '${s['price']}',
      yearly ? '年' : '月',
      yearly ? '${s['month'] ?? ''}' : '',
      '${s['day']}',
      _escape('${s['genre']}'),
      (s['includeInMonthly'] ?? true) ? '込' : '外',
      (s['isReviewing'] ?? false) ? '検討中' : '',
      _usageToLabel[s['usage']] ?? '',
      (s['showInMonthly'] ?? false) ? 'はい' : '',
      color == null ? '' : color.toRadixString(16).toUpperCase().padLeft(8, '0'),
    ].join(','));
  }
  return b.toString();
}

/// CSVの文字列を行と列に分ける(引用符・カンマ・改行を含む値に対応)
List<List<String>> parseCsvRows(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var i = 0;
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) i = 1; // BOM
  void endCell() { row.add(cell.toString()); cell.clear(); }
  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }
  for (; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') { cell.write('"'); i++; }
        else { inQuotes = false; }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      endCell();
    } else if (ch == '\n') {
      endRow();
    } else if (ch == '\r') {
      if (i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

int? _toInt(String v) => int.tryParse(v.replaceAll(RegExp(r'[,，円\s]'), ''));

CsvImport parseCsv(String text) {
  final rows = parseCsvRows(text);
  if (rows.isEmpty) return const CsvImport([], {}, ['データがありません']);

  final header = rows.first.map((h) => h.trim()).toList();
  int col(List<String> names) {
    for (final n in names) {
      final i = header.indexOf(n);
      if (i >= 0) return i;
    }
    return -1;
  }
  final cName = col(['名前', 'サービス名']);
  final cPrice = col(['金額', '価格']);
  if (cName < 0 || cPrice < 0) {
    return const CsvImport([], {}, ['「名前」と「金額」の列が見つかりません。このアプリで書き出したCSVを選んでください']);
  }
  final cCycle = col(['サイクル', '支払いサイクル']);
  final cMonth = col(['更新月']);
  final cDay = col(['更新日', '支払日']);
  final cGenre = col(['ジャンル', 'カテゴリ']);
  final cCounted = col(['計上']);
  final cReview = col(['検討中']);
  final cUsage = col(['利用頻度']);
  final cShow = col(['月額にも含む']);
  final cColor = col(['ジャンル色']);

  String at(List<String> r, int c) => (c >= 0 && c < r.length) ? r[c].trim() : '';

  final items = <Map<String, dynamic>>[];
  final colors = <String, int>{};
  final errors = <String>[];
  for (var n = 1; n < rows.length; n++) {
    final r = rows[n];
    final line = n + 1; // 見出しを1行目として数える
    final name = at(r, cName);
    final price = _toInt(at(r, cPrice));
    if (name.isEmpty) { errors.add('$line行目: 名前が空です'); continue; }
    if (price == null || price < 0) { errors.add('$line行目（$name）: 金額が数字ではありません'); continue; }

    final cycle = at(r, cCycle);
    final yearly = cycle.startsWith('年');
    final day = _toInt(at(r, cDay)) ?? 1;
    final month = _toInt(at(r, cMonth)) ?? 1;
    final genre = at(r, cGenre).isEmpty ? 'その他' : at(r, cGenre);

    items.add({
      'name': name, 'price': price,
      'isYearly': yearly,
      'month': month.clamp(1, 12), 'day': day.clamp(1, 31),
      'genre': genre,
      'includeInMonthly': at(r, cCounted) != '外',
      'isReviewing': at(r, cReview).isNotEmpty,
      'usage': _labelToUsage[at(r, cUsage)],
      'showInMonthly': at(r, cShow).isNotEmpty,
    });

    final colorText = at(r, cColor);
    if (colorText.isNotEmpty) {
      final c = int.tryParse(colorText, radix: 16);
      if (c != null) colors[genre] = c;
    }
  }
  return CsvImport(items, colors, errors);
}
