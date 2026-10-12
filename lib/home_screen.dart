import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'add_screen.dart';
import 'app_pill.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- 状態管理 ---
  List<Map<String, dynamic>> _subs = [];
  // ★デフォルトカテゴリに「クレカ」と「AI」を追加
  List<String> _genres = ['動画', '音楽', '携帯代', '家賃', 'クレカ', 'AI', 'その他'];
  Map<String, int> _genreColors = {};
  String _searchQuery = '';
  String _sortBy = 'date';
  String? _filterGenre; // nullなら全カテゴリ
  int _touchedIndex = -1; // 分析グラフでタップ中のカテゴリ
  bool _isYearlyView = false;
  final _formatter = NumberFormat('#,###');

  // ★復活！こだわりの21色パレット
  final List<Color> themeColors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.pink, Colors.teal,
    const Color(0xFF90CAF9), const Color(0xFFA5D6A7), const Color(0xFFF48FB1), 
    const Color(0xFFCE93D8), const Color(0xFFFFCC80), const Color(0xFFFFF59D), const Color(0xFF80DEEA),
    const Color(0xFF000080), const Color(0xFF000000), const Color(0xFF1A237E),
    const Color(0xFF0D47A1), const Color(0xFF004D40), const Color(0xFF37474F), const Color(0xFF212121),
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // --- データ保存・読込 ---
  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _subs = List<Map<String, dynamic>>.from(json.decode(prefs.getString('subscription_list') ?? '[]'));
      // デフォルト値にも「クレカ」「AI」を反映
      _genres = List<String>.from(json.decode(prefs.getString('genre_list') ?? '["動画", "音楽", "携帯代", "家賃", "クレカ", "AI", "その他"]'));
      _genreColors = Map<String, int>.from(json.decode(prefs.getString('genre_colors') ?? '{}'));
      _sortList();
    });
  }

  Future<void> _saveAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription_list', json.encode(_subs));
    await prefs.setString('genre_list', json.encode(_genres));
    await prefs.setString('genre_colors', json.encode(_genreColors));
  }

  // --- 便利計算 ---
  // どの背景でも見えるように、明るさを範囲内に収める(黒や薄い黄色対策)
  Color _getGenreColor(String genre) {
    final base = _genreColors.containsKey(genre) ? Color(_genreColors[genre]!) : Colors.grey.shade500;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(base);
    final l = dark ? hsl.lightness.clamp(0.55, 0.85) : hsl.lightness.clamp(0.28, 0.52);
    return hsl.withLightness(l.toDouble()).toColor();
  }

  Color _onColor(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : Colors.black87;

  int _calculateDaysUntil(int? month, int day, bool isYearly) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime nextDate;
    if (isYearly && month != null) {
      nextDate = DateTime(now.year, month, day);
      if (nextDate.isBefore(today)) nextDate = DateTime(now.year + 1, month, day);
    } else {
      nextDate = DateTime(now.year, now.month, day);
      if (nextDate.isBefore(today)) nextDate = DateTime(now.year, now.month + 1, day);
    }
    return nextDate.difference(today).inDays;
  }

  int get _totalMonthlyPrice {
    return _subs.fold(0, (sum, item) {
      if (!(item['includeInMonthly'] ?? true)) return sum;
      int p = item['price'] as int;
      return sum + ((item['isYearly'] ?? false) ? (p / 12).round() : p);
    });
  }

  int get _reviewTotalPrice {
    return _subs.fold(0, (sum, item) {
      if (!(item['isReviewing'] ?? false)) return sum;
      int p = item['price'] as int;
      return sum + ((item['isYearly'] ?? false) ? (p / 12).round() : p);
    });
  }

  void _sortList() {
    setState(() {
      if (_sortBy == 'date') {
        _subs.sort((a, b) => _calculateDaysUntil(a['month'], a['day'], a['isYearly'] ?? false)
            .compareTo(_calculateDaysUntil(b['month'], b['day'], b['isYearly'] ?? false)));
      } else {
        _subs.sort((a, b) => (b['price'] as int).compareTo(a['price'] as int));
      }
    });
  }

  // --- CSV出力 ---
  void _exportToCSV() {
    String csv = '\uFEFF名前,金額,サイクル,更新月,更新日,ジャンル,計上,検討中\n';
    for (var sub in _subs) {
      csv += '${sub['name']},${sub['price']},${sub['isYearly'] ? "年" : "月"},${sub['month'] ?? ""},${sub['day']},${sub['genre']},${sub['includeInMonthly'] ? "込" : "外"},${sub['isReviewing'] ? "検討中" : ""}\n';
    }
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)..setAttribute("download", "subsc_data.csv")..click();
    html.Url.revokeObjectUrl(url);
  }

  // --- UI構成 ---
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredSubs = _subs.where((sub) =>
        sub['name'].toLowerCase().contains(_searchQuery.toLowerCase()) &&
        (_filterGenre == null || sub['genre'] == _filterGenre)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('サブスク管理 Pro', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1)),
          actions: [
            // ★カテゴリ管理ボタンを分かりやすくラベル付きに（または目立つアイコンに）
            TextButton.icon(
              onPressed: _showGenreManagement,
              icon: const Icon(Icons.category_rounded),
              label: const Text('カテゴリ設定', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            IconButton(icon: const Icon(Icons.tune_rounded), onPressed: () => _showSettings(isDark)),
          ],
          bottom: const TabBar(tabs: [Tab(text: '一覧'), Tab(text: '分析レポート')]),
        ),
        body: TabBarView(
          children: [
            Column(children: [
              Expanded(child: _buildListView(filteredSubs)),
            ]),
            _buildAnalysisTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddScreen(),
          label: const Text('サブスクを追加', style: TextStyle(fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  Color _headerEnd(ColorScheme cs) {
    if (cs.brightness == Brightness.dark) return Color.lerp(cs.primary, cs.tertiary, 0.55)!;
    final hsl = HSLColor.fromColor(cs.primary);
    return hsl.withHue((hsl.hue + 35) % 360).withSaturation((hsl.saturation + 0.1).clamp(0.0, 1.0)).toColor();
  }

  Widget _buildSummaryHeader() {
    final cs = Theme.of(context).colorScheme;
    final on = cs.onPrimary;
    int displayPrice = _isYearlyView ? _totalMonthlyPrice * 12 : _totalMonthlyPrice;
    int displayReviewPrice = _isYearlyView ? _reviewTotalPrice * 12 : _reviewTotalPrice;
    return Container(
      padding: const EdgeInsets.all(22), margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [cs.primary, _headerEnd(cs)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isYearlyView ? '年間合計' : '月間合計', style: TextStyle(color: on.withOpacity(0.8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text('${_formatter.format(displayPrice)} 円', style: TextStyle(fontSize: 38, color: on, fontWeight: FontWeight.w900, letterSpacing: -1))),
          ])),
          Icon(Icons.auto_graph_rounded, color: on.withOpacity(0.35), size: 48),
        ]),
        if (displayReviewPrice > 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: on.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Icons.savings_rounded, size: 18, color: on),
              const SizedBox(width: 8),
              Expanded(child: Text('解約すると節約できる額', style: TextStyle(color: on, fontSize: 13, fontWeight: FontWeight.bold))),
              Text('- ${_formatter.format(displayReviewPrice)} 円', style: TextStyle(color: on, fontSize: 16, fontWeight: FontWeight.w900)),
            ]),
          ),
        ]
      ]),
    );
  }

  Widget _buildToggleSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('月額表示'), icon: Icon(Icons.calendar_month)),
            ButtonSegment(value: true, label: Text('年額表示'), icon: Icon(Icons.event_note)),
          ],
          selected: <bool>{_isYearlyView},
          onSelectionChanged: (set) => setState(() => _isYearlyView = set.first),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'サービス名で検索...', prefixIcon: const Icon(Icons.search),
          filled: true, isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  // カテゴリ絞り込み + 並び替え
  Widget _buildFilterBar() {
    return Column(children: [
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppPill(label: 'すべて', selected: _filterGenre == null, onTap: () => setState(() => _filterGenre = null)),
            ),
            ..._genres.map((g) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppPill(
                label: g, dotColor: _getGenreColor(g), selected: _filterGenre == g,
                onTap: () => setState(() => _filterGenre = _filterGenre == g ? null : g),
              ),
            )),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text('${_subs.length}件', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.sort, size: 18, color: Colors.grey),
          const SizedBox(width: 4),
          DropdownButton<String>(
            value: _sortBy, underline: const SizedBox.shrink(), isDense: true,
            items: const [
              DropdownMenuItem(value: 'date', child: Text('支払日が近い順')),
              DropdownMenuItem(value: 'price', child: Text('金額が高い順')),
            ],
            onChanged: (v) { if (v != null) { _sortBy = v; _sortList(); } },
          ),
        ]),
      ),
    ]);
  }

  // 支払日までの日数に応じたバッジ
  Widget _buildDaysBadge(int diff) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color c = diff <= 3
        ? (dark ? Colors.red.shade300 : Colors.red.shade700)
        : (diff <= 7 ? (dark ? Colors.orange.shade300 : Colors.deepOrange.shade700) : Theme.of(context).colorScheme.onSurfaceVariant);
    final String label = diff == 0 ? '今日' : 'あと$diff日';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildTag(String text, Color c, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.22), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 3)],
        Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> list) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96), // FABと重ならない余白
      itemCount: list.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(children: [
            _buildSummaryHeader(),
            _buildToggleSwitch(),
            _buildSearchField(),
            _buildFilterBar(),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Column(children: [
                  Icon(Icons.inbox_rounded, size: 56, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('該当するサブスクがありません', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ]),
              ),
          ]);
        }
        final item = list[index - 1];
        final bool include = item['includeInMonthly'] ?? true;
        final bool reviewing = item['isReviewing'] ?? false;
        final bool yearly = item['isYearly'] ?? false;
        final int diff = _calculateDaysUntil(item['month'], item['day'], yearly);
        final int itemPrice = _isYearlyView ? (yearly ? item['price'] : item['price'] * 12) : (yearly ? (item['price'] / 12).round() : item['price']);
        final Color gc = _getGenreColor(item['genre']);
        final String dateText = yearly ? '毎年${item['month']}月${item['day']}日' : '毎月${item['day']}日';
        final String unit = _isYearlyView ? '/年' : '/月';

        return Card(
          elevation: 0, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          clipBehavior: Clip.antiAlias,
          color: reviewing ? Colors.orange.withOpacity(0.12) : (include ? null : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: reviewing ? Colors.orange : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5))),
          child: InkWell(
            onTap: () => _openAddScreen(index: _subs.indexOf(item)),
            onLongPress: () => _deleteSub(_subs.indexOf(item)),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 6, color: gc), // カテゴリ色のライン
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, decoration: include ? null : TextDecoration.lineThrough, color: include ? null : Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        _buildDaysBadge(diff),
                        Text(dateText, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        _buildTag(item['genre'], gc),
                        if (yearly) _buildTag('年払い', Colors.indigo),
                        if (reviewing) _buildTag('検討中', Colors.orange, icon: Icons.warning_amber_rounded),
                        if (!include) _buildTag('合計外', Colors.grey),
                      ]),
                    ])),
                    const SizedBox(width: 8),
                    Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${_formatter.format(itemPrice)}円', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      Text(unit, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ]),
                  ]),
                )),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _analysisCard({required String title, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          child,
        ]),
      ),
    );
  }

  // 横棒1本分: 色マーク + 名前 + 棒 + 金額/割合
  Widget _barRow({required String label, required Color color, required double ratio, required String amount, String? sub, bool active = true}) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: active ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(amount, style: const TextStyle(fontWeight: FontWeight.w900)),
            if (sub != null) SizedBox(width: 52, child: Text(sub, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0), minHeight: 8, color: color, backgroundColor: cs.onSurface.withOpacity(0.08)),
          ),
        ]),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    final cs = Theme.of(context).colorScheme;
    final mul = _isYearlyView ? 12 : 1;
    int monthlyOf(Map<String, dynamic> item) => (item['isYearly'] ?? false) ? (item['price'] / 12).round() : item['price'] as int;

    final counted = _subs.where((i) => i['includeInMonthly'] ?? true).toList();
    final Map<String, int> totals = {};
    for (var item in counted) {
      totals[item['genre']] = (totals[item['genre']] ?? 0) + monthlyOf(item) * mul;
    }
    if (totals.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.donut_large_rounded, size: 56, color: cs.onSurfaceVariant),
        const SizedBox(height: 8),
        Text('分析データがありません', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
      ]));
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    final top = counted.toList()..sort((a, b) => monthlyOf(b).compareTo(monthlyOf(a)));
    final topItems = top.take(5).toList();
    final touched = (_touchedIndex >= 0 && _touchedIndex < entries.length) ? entries[_touchedIndex] : null;
    final unitLabel = _isYearlyView ? '年間合計' : '月間合計';

    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 96),
      children: [
        _analysisCard(
          title: 'カテゴリ別の割合',
          child: Column(children: [
            SizedBox(
              height: 240,
              child: Stack(alignment: Alignment.center, children: [
                PieChart(PieChartData(
                  startDegreeOffset: 270, sectionsSpace: 3, centerSpaceRadius: 82,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(touchCallback: (event, resp) {
                    final i = resp?.touchedSection?.touchedSectionIndex ?? -1;
                    if (!event.isInterestedForInteractions || i < 0) {
                      if (_touchedIndex != -1) setState(() => _touchedIndex = -1);
                    } else if (i != _touchedIndex) {
                      setState(() => _touchedIndex = i);
                    }
                  }),
                  sections: List.generate(entries.length, (i) => PieChartSectionData(
                    color: _getGenreColor(entries[i].key),
                    value: entries[i].value.toDouble(),
                    radius: _touchedIndex == i ? 36 : 28,
                    showTitle: false,
                  )),
                )),
                // 中心: 合計 or タップ中カテゴリの詳細
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(touched?.key ?? unitLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text('${_formatter.format(touched?.value ?? total)}円', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  if (touched != null)
                    Text('${(touched.value / total * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _getGenreColor(touched.key))),
                ]),
              ]),
            ),
            Text('リングをタップすると詳細が見られます', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
        ),
        _analysisCard(
          title: 'カテゴリ別ランキング',
          child: Column(children: List.generate(entries.length, (i) {
            final e = entries[i];
            return GestureDetector(
              onTap: () => setState(() => _touchedIndex = _touchedIndex == i ? -1 : i),
              behavior: HitTestBehavior.opaque,
              child: _barRow(
                label: e.key, color: _getGenreColor(e.key), ratio: e.value / entries.first.value,
                amount: '${_formatter.format(e.value)}円', sub: '${(e.value / total * 100).toStringAsFixed(0)}%',
                active: _touchedIndex == -1 || _touchedIndex == i,
              ),
            );
          })),
        ),
        _analysisCard(
          title: '高いサブスク TOP${topItems.length}',
          child: Column(children: [
            for (final item in topItems)
              _barRow(
                label: item['name'], color: _getGenreColor(item['genre']),
                ratio: monthlyOf(item) / monthlyOf(topItems.first),
                amount: '${_formatter.format(monthlyOf(item) * mul)}円',
                sub: '${(monthlyOf(item) * mul / total * 100).toStringAsFixed(0)}%',
              ),
          ]),
        ),
      ],
    );
  }

  // --- カテゴリ管理・色選択 ---
  void _showGenreManagement() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(builder: (context, setModalState) => Container(
        padding: const EdgeInsets.all(24), height: 600,
        child: Column(children: [
          const Text('カテゴリ管理・追加', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const Text('好きなカテゴリを自由に追加したり、色を塗れます', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 24),
          Expanded(child: ListView.builder(
            itemCount: _genres.length,
            itemBuilder: (context, i) => ListTile(
              leading: GestureDetector(
                onTap: () => _pickGenreColor(_genres[i], setModalState),
                child: CircleAvatar(backgroundColor: _getGenreColor(_genres[i]), child: Icon(Icons.palette, size: 14, color: _onColor(_getGenreColor(_genres[i])))),
              ),
              title: Text(_genres[i], style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () {
                setState(() { setModalState(() => _genres.removeAt(i)); _saveAllData(); });
              }),
            ),
          )),
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextField(
              decoration: InputDecoration(
                hintText: '新しいカテゴリ名を入力...', 
                prefixIcon: const Icon(Icons.add_box_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (val) { if (val.isNotEmpty) setState(() { setModalState(() => _genres.add(val)); _saveAllData(); }); },
            ),
          ),
        ]),
      )),
    );
  }

  void _pickGenreColor(String genre, StateSetter setModalState) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text('$genre の色を選択'),
      content: SizedBox(
        width: 300,
        child: Wrap(spacing: 10, runSpacing: 10, children: themeColors.map((c) => GestureDetector(
          onTap: () { setState(() { setModalState(() => _genreColors[genre] = c.value); _saveAllData(); }); Navigator.pop(context); },
          child: CircleAvatar(backgroundColor: c, radius: 22),
        )).toList()),
      ),
    ));
  }

  void _showSettings(bool isDark) {
    showModalBottomSheet(context: context, builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(title: const Text('ダークモード'), secondary: const Icon(Icons.dark_mode), value: isDark, onChanged: (v) { MyApp.of(context)?.toggleDarkMode(v); Navigator.pop(context); }),
        ListTile(leading: const Icon(Icons.download), title: const Text('CSVでエクスポート'), onTap: () { _exportToCSV(); Navigator.pop(context); }),
        const Divider(),
        const Text('テーマカラー設定 (21色)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(height: 120, child: GridView.count(crossAxisCount: 7, children: themeColors.map((c) => GestureDetector(
          onTap: () { MyApp.of(context)?.changeColor(c); Navigator.pop(context); },
          child: Padding(padding: const EdgeInsets.all(4), child: CircleAvatar(backgroundColor: c)),
        )).toList())),
      ]),
    ));
  }

  void _deleteSub(int i) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('削除確認'), content: const Text('このサブスクを削除しますか？'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
      TextButton(onPressed: () async { setState(() => _subs.removeAt(i)); await _saveAllData(); Navigator.pop(context); }, child: const Text('削除', style: TextStyle(color: Colors.red)))],
    ));
  }

  Future<void> _openAddScreen({int? index}) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddScreen(editData: index != null ? _subs[index] : null, genres: _genres)));
    if (result != null) { setState(() { if (index != null) _subs[index] = result; else _subs.add(result); _sortList(); }); _saveAllData(); }
  }
}