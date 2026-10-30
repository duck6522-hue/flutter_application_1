import 'package:intl/intl.dart';

/// 他のAI(ChatGPT・Claude・Gemini など)に貼り付けて、サブスクの現状を診断してもらうためのプロンプトを作る。
/// 画面の状態に左右されないよう、登録済みの全サブスクを対象にする。
String buildDiagnosisPrompt({
  required List<Map<String, dynamic>> subs,
  required int Function(int? month, int day, bool isYearly) daysUntil,
}) {
  final yen = NumberFormat('#,###');
  String y(int v) => '${yen.format(v)}円';

  bool isYearly(Map<String, dynamic> i) => i['isYearly'] ?? false;
  bool counted(Map<String, dynamic> i) => i['includeInMonthly'] ?? true;
  bool reviewing(Map<String, dynamic> i) => i['isReviewing'] ?? false;
  // 月額換算(年払いは12分割)
  int monthly(Map<String, dynamic> i) => isYearly(i) ? ((i['price'] as int) / 12).round() : i['price'] as int;

  final active = subs.where(counted).toList();
  final monthlyTotal = active.fold<int>(0, (s, i) => s + monthly(i));
  final monthlyBilled = active.where((i) => !isYearly(i)).fold<int>(0, (s, i) => s + (i['price'] as int));
  final yearlyBilled = active.where(isYearly).fold<int>(0, (s, i) => s + (i['price'] as int));
  final reviewTotal = subs.where(reviewing).fold<int>(0, (s, i) => s + monthly(i));

  // カテゴリ別(月額換算・多い順)
  final byGenre = <String, int>{};
  for (final i in active) {
    byGenre[i['genre']] = (byGenre[i['genre']] ?? 0) + monthly(i);
  }
  final genreLines = (byGenre.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .map((e) => '- ${e.key}: ${y(e.value)}/月${monthlyTotal > 0 ? '（${(e.value / monthlyTotal * 100).toStringAsFixed(0)}%）' : ''}')
      .join('\n');

  // 明細(月額換算が高い順)
  final sorted = subs.toList()..sort((a, b) => monthly(b).compareTo(monthly(a)));
  final today = DateTime.now();
  final lines = <String>[];
  for (var n = 0; n < sorted.length; n++) {
    final i = sorted[n];
    final yearly = isYearly(i);
    final days = daysUntil(i['month'], i['day'], yearly);
    final next = DateTime(today.year, today.month, today.day).add(Duration(days: days));
    final price = yearly ? '${y(i['price'])}/年（月換算 ${y(monthly(i))}）' : '${y(i['price'])}/月';
    final flags = [
      if (reviewing(i)) '解約検討中',
      if (!counted(i)) '合計外',
    ];
    lines.add('${n + 1}. ${i['name']} | $price | カテゴリ: ${i['genre']} | 次回支払い: ${next.month}/${next.day}（あと$days日）${flags.isEmpty ? '' : ' | ${flags.join('・')}'}');
  }

  final stamp = DateFormat('yyyy/MM/dd').format(today);
  return '''あなたは家計とサブスクリプション管理に詳しいファイナンシャルアドバイザーです。
以下は私が契約している定期支払い（サブスク）の一覧です。内容を診断して、無駄を減らすための具体的な提案をしてください。

【前提】
- 通貨は日本円、作成日は $stamp です。
- 年払いは12分割して月額換算しています。
- 「解約検討中」は、私自身が見直したいと思っているものです。
- 「合計外」は、集計から除外している項目です（参考情報）。

【サマリー】
- 月額換算の合計: ${y(monthlyTotal)}（年間 ${y(monthlyTotal * 12)}）
- 内訳: 月払い ${y(monthlyBilled)}/月、年払い ${y(yearlyBilled)}/年
- 契約数: ${subs.length}件（うち解約検討中の月額換算合計 ${y(reviewTotal)}）

【カテゴリ別（月額換算）】
${genreLines.isEmpty ? '- （なし）' : genreLines}

【明細（月額換算が高い順）】
${lines.isEmpty ? '（登録なし）' : lines.join('\n')}

【診断してほしいこと】
1. 支出全体の評価（カテゴリの配分は妥当か、固定費として重すぎないか）
2. 見直し候補を優先順位つきで。理由と、解約・プラン変更・年払い切り替え・家族プランなどの具体策も
3. 機能や用途が重複・類似しているサービスがないか
4. 月払いと年払いを切り替えると安くなりそうなもの（割引率は断定せず、確認方法を示す）
5. 見直しを実行した場合の節約額の試算（月額・年額）
6. 判断に必要な追加情報があれば、最初に最大3つまで質問してください

【回答の形式】
- 最初に結論を3行でまとめる
- 見直し候補は表にする（サービス名／おすすめの対応／節約額／理由）
- 最後に「今日やる最初の1アクション」を1つだけ示す
- 最新の料金やプラン内容は変わるため、断定できないものは推測と明記し、公式サイトでの確認を促す
''';
}
