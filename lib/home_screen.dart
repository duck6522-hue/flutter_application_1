import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'add_screen.dart';
import 'app_pill.dart';
import 'main.dart';

// 一覧・合計の表示モード
enum ViewMode { monthly, yearly, monthlyOnly, yearlyOnly }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- 状態管理 ---
  List<Map<String, dynamic>> _subs = [];
  // ★デフォルトカテゴリに「クレカ」と「AI」を追加
  List<String> _genres = ['動画', '音楽', '携帯代', '家賃', 'クレカ', 'AI', '副業', 'その他'];
  Map<String, int> _genreColors = {};
  String _searchQuery = '';
  String _sortBy = 'price'; // 金額が高い順がデフォルト
  String? _filterGenre; // nullなら全カテゴリ
  final GlobalKey _captureKey = GlobalKey(); // 画面保存用
  int _touchedIndex = -1; // 分析グラフでタップ中のカテゴリ
  ViewMode _viewMode = ViewMode.monthly; // 一番よく見る月額表示がデフォルト
  bool get _isYearlyView => _viewMode == ViewMode.yearly || _viewMode == ViewMode.yearlyOnly;
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
      _genres = List<String>.from(json.decode(prefs.getString('genre_list') ?? '["動画", "音楽", "携帯代", "家賃", "クレカ", "AI", "副業", "その他"]'));
      _genreColors = Map<String, int>.from(json.decode(prefs.getString('genre_colors') ?? '{}'));
      // 既存の保存データにも「副業」を1度だけ追加する(後で削除しても復活しない)
      if (!(prefs.getBool('genre_added_sidejob') ?? false)) {
        if (!_genres.contains('副業')) {
          final i = _genres.indexOf('その他');
          _genres.insert(i >= 0 ? i : _genres.length, '副業');
        }
        prefs.setBool('genre_added_sidejob', true);
        prefs.setString('genre_list', json.encode(_genres));
      }
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

  // 表示モードごとに、どのサブスクを対象にするか
  //  月額: 月払い + 「月額にも含める」をオンにした年払い / 年額: 全部
  //  月払いのみ: 月払いだけ / 年払いのみ: 年払いだけ
  bool _inView(Map<String, dynamic> item) {
    final yearly = item['isYearly'] ?? false;
    switch (_viewMode) {
      case ViewMode.monthly: return !yearly || (item['showInMonthly'] ?? false);
      case ViewMode.yearly: return true;
      case ViewMode.monthlyOnly: return !yearly;
      case ViewMode.yearlyOnly: return yearly;
    }
  }

  int get _totalPrice => _subs
      .where((i) => (i['includeInMonthly'] ?? true) && _inView(i))
      .fold(0, (sum, i) => sum + _displayPrice(i));

  int get _reviewPrice => _subs
      .where((i) => (i['isReviewing'] ?? false) && _inView(i))
      .fold(0, (sum, i) => sum + _displayPrice(i));

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

  // --- 画面を画像(PNG)で保存 ---
  Future<void> _saveScreenshot() async {
    try {
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final blob = html.Blob([data.buffer.asUint8List()], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      html.AnchorElement(href: url)..setAttribute('download', 'subsc_$stamp.png')..click();
      html.Url.revokeObjectUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('画面を画像で保存しました'), behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('画像の保存に失敗しました'), behavior: SnackBarBehavior.floating));
      }
    }
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
        _inView(sub) &&
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
            IconButton(tooltip: '画面を画像で保存', icon: const Icon(Icons.photo_camera_outlined), onPressed: _saveScreenshot),
            IconButton(icon: const Icon(Icons.tune_rounded), onPressed: () => _showSettings(isDark)),
          ],
          bottom: const TabBar(tabs: [Tab(text: '一覧'), Tab(text: '分析レポート')]),
        ),
        body: RepaintBoundary(
          key: _captureKey,
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBarView(
              children: [
                Column(children: [
                  Expanded(child: _buildListView(filteredSubs)),
                ]),
                _buildAnalysisTab(),
              ],
            ),
          ),
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

  String get _modeTitle {
    switch (_viewMode) {
      case ViewMode.monthly: return '月間合計';
      case ViewMode.yearly: return '年間合計';
      case ViewMode.monthlyOnly: return '月払いの合計';
      case ViewMode.yearlyOnly: return '年払いの合計';
    }
  }

  Widget _headerTile({required String label, required int value, required String unit, required IconData icon, required Color on, String? sub}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: on.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: on.withOpacity(0.85)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on.withOpacity(0.85))),
        ]),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text.rich(TextSpan(children: [
          TextSpan(text: _formatter.format(value), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: on)),
          TextSpan(text: ' 円/$unit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: on.withOpacity(0.85))),
        ]))),
        if (sub != null) Text(sub, style: TextStyle(fontSize: 11, color: on.withOpacity(0.8))),
      ]),
    );
  }

  Widget _buildSummaryHeader() {
    final cs = Theme.of(context).colorScheme;
    final on = cs.onPrimary;
    final int displayPrice = _totalPrice;
    final int displayReviewPrice = _reviewPrice;
    final int excludedYearly = _viewMode != ViewMode.monthly ? 0 : _subs.where((i) => (i['isYearly'] ?? false) && (i['includeInMonthly'] ?? true) && !_inView(i)).length;
    final counted = _subs.where((i) => i['includeInMonthly'] ?? true);
    final int monthlyBilled = counted.where((i) => !(i['isYearly'] ?? false)).fold(0, (sum, i) => sum + (i['price'] as int));
    final int yearlyBilled = counted.where((i) => i['isYearly'] ?? false).fold(0, (sum, i) => sum + (i['price'] as int));
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
            Text(_modeTitle, style: TextStyle(color: on.withOpacity(0.8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text('${_formatter.format(displayPrice)} 円', style: TextStyle(fontSize: 38, color: on, fontWeight: FontWeight.w900, letterSpacing: -1))),
            if (excludedYearly > 0) Text('年払い$excludedYearly件は含まず', style: TextStyle(fontSize: 12, color: on.withOpacity(0.8))),
            if (_viewMode == ViewMode.yearlyOnly && displayPrice > 0) Text('月あたり 約${_formatter.format((displayPrice / 12).round())}円', style: TextStyle(fontSize: 12, color: on.withOpacity(0.8))),
            if (_viewMode == ViewMode.monthlyOnly && displayPrice > 0) Text('年間 ${_formatter.format(displayPrice * 12)}円', style: TextStyle(fontSize: 12, color: on.withOpacity(0.8))),
          ])),
          Icon(Icons.auto_graph_rounded, color: on.withOpacity(0.35), size: 48),
        ]),
        if (_viewMode == ViewMode.monthly || _viewMode == ViewMode.yearly) ...[
        const SizedBox(height: 14),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _headerTile(label: '月払い', value: monthlyBilled * (_isYearlyView ? 12 : 1), unit: _isYearlyView ? '年' : '月', icon: Icons.calendar_month_rounded, on: on)),
          const SizedBox(width: 10),
          Expanded(child: _headerTile(label: '年払い', value: yearlyBilled, unit: '年', icon: Icons.event_note_rounded, on: on, sub: _isYearlyView || yearlyBilled == 0 ? null : '月あたり ${_formatter.format((yearlyBilled / 12).round())}円')),
        ])),
        ],
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
        child: SegmentedButton<ViewMode>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
          ),
          segments: const [
            ButtonSegment(value: ViewMode.monthly, label: Text('月額', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
            ButtonSegment(value: ViewMode.yearly, label: Text('年額', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
            ButtonSegment(value: ViewMode.monthlyOnly, label: Text('月払いのみ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
            ButtonSegment(value: ViewMode.yearlyOnly, label: Text('年払いのみ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
          ],
          selected: <ViewMode>{_viewMode},
          onSelectionChanged: (set) => setState(() => _viewMode = set.first),
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

  int _displayPrice(Map<String, dynamic> item) {
    final yearly = item['isYearly'] ?? false;
    return _isYearlyView ? (yearly ? item['price'] : item['price'] * 12) : (yearly ? (item['price'] / 12).round() : item['price']);
  }

  // 月払い/年払いの区切り見出し(件数と小計つき)
  Widget _buildSectionHeader(bool yearly, List<Map<String, dynamic>> items) {
    final cs = Theme.of(context).colorScheme;
    final counted = items.where((i) => i['includeInMonthly'] ?? true);
    // 小計は表示中の単位(月/年)で出す
    final subtotal = counted.fold<int>(0, (sum, i) => sum + _displayPrice(i));
    final unit = _isYearlyView ? '年' : '月';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: cs.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(yearly ? Icons.event_note_rounded : Icons.calendar_month_rounded, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Text(yearly ? '年払い' : '月払い', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Text('${items.length}件', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
        const Spacer(),
        Text('小計 ${_formatter.format(subtotal)}円/$unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> list) {
    // 月払い → 年払いの順に、見出しを挟んで並べる
    final monthly = list.where((i) => !(i['isYearly'] ?? false)).toList();
    final yearlyItems = list.where((i) => i['isYearly'] ?? false).toList();
    final List<Object> rows = [
      if (monthly.isNotEmpty) ...[_buildSectionHeader(false, monthly), ...monthly],
      if (yearlyItems.isNotEmpty) ...[_buildSectionHeader(true, yearlyItems), ...yearlyItems],
    ];
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96), // FABと重ならない余白
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(children: [
            _buildSummaryHeader(),
            _buildToggleSwitch(),
            _buildSearchField(),
            _buildFilterBar(),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(48),
                child: Column(children: [
                  const Icon(Icons.inbox_rounded, size: 56, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(_viewMode == ViewMode.yearlyOnly ? '年払いのサブスクがありません' : (_viewMode == ViewMode.monthlyOnly ? '月払いのサブスクがありません' : '該当するサブスクがありません'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ]),
              ),
          ]);
        }
        final row = rows[index - 1];
        if (row is Widget) return row;
        final item = row as Map<String, dynamic>;
        final bool include = item['includeInMonthly'] ?? true;
        final bool reviewing = item['isReviewing'] ?? false;
        final bool yearly = item['isYearly'] ?? false;
        final int diff = _calculateDaysUntil(item['month'], item['day'], yearly);
        final int itemPrice = _displayPrice(item);
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
                        if (yearly && (item['showInMonthly'] ?? false)) _buildTag('月額にも含む', Colors.indigo),
                        if (reviewing) _buildTag('検討中', Colors.orange, icon: Icons.warning_amber_rounded),
                        if (!include) _buildTag('合計外', Colors.grey),
                      ]),
                    ])),
                    const SizedBox(width: 8),
                    Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      // 年払いは実際の請求額を主表示にし、月換算は補足にする
                      Text('${_formatter.format(yearly ? item['price'] : itemPrice)}円', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      Text(
                        yearly ? (_isYearlyView ? '/年' : '/年・月あたり${_formatter.format(itemPrice)}円') : unit,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
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
    final counted = _subs.where((i) => (i['includeInMonthly'] ?? true) && _inView(i)).toList();
    final Map<String, int> totals = {};
    for (var item in counted) {
      totals[item['genre']] = (totals[item['genre']] ?? 0) + _displayPrice(item);
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
    final top = counted.toList()..sort((a, b) => _displayPrice(b).compareTo(_displayPrice(a)));
    final topItems = top.take(5).toList();
    final touched = (_touchedIndex >= 0 && _touchedIndex < entries.length) ? entries[_touchedIndex] : null;
    final unitLabel = _modeTitle;

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
                ratio: _displayPrice(item) / _displayPrice(topItems.first),
                amount: '${_formatter.format(_displayPrice(item))}円',
                sub: '${(_displayPrice(item) / total * 100).toStringAsFixed(0)}%',
              ),
          ]),
        ),
      ],
    );
  }

  // --- カテゴリ管理・色選択 ---
  Widget _sheetHandle() => Center(
    child: Container(
      width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
    ),
  );

  void _showGenreManagement() {
    final addController = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => StatefulBuilder(builder: (context, setModalState) {
        final cs = Theme.of(context).colorScheme;
        void addGenre() {
          final name = addController.text.trim();
          if (name.isEmpty) return;
          if (_genres.contains(name)) {
            ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('同じ名前のカテゴリがあります'), behavior: SnackBarBehavior.floating));
            return;
          }
          setState(() { setModalState(() => _genres.add(name)); _saveAllData(); });
          addController.clear();
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(),
            const Text('カテゴリ設定', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('左の色の丸をタップすると色を変えられます', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 16),
            Flexible(child: ListView.separated(
              shrinkWrap: true,
              itemCount: _genres.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final g = _genres[i];
                final used = _subs.where((e) => e['genre'] == g).length;
                final c = _getGenreColor(g);
                return Material(
                  color: cs.brightness == Brightness.dark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: GestureDetector(
                      onTap: () => _pickGenreColor(g, setModalState),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        child: Icon(Icons.palette_outlined, size: 18, color: _onColor(c)),
                      ),
                    ),
                    title: Text(g, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(used == 0 ? '未使用' : '$used件で使用中', style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: used == 0 ? cs.error : cs.outline),
                      onPressed: () {
                        if (used > 0) {
                          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('「$g」は$used件のサブスクで使用中のため削除できません'), behavior: SnackBarBehavior.floating));
                          return;
                        }
                        setState(() { setModalState(() => _genres.removeAt(i)); _saveAllData(); });
                      },
                    ),
                  ),
                );
              },
            )),
            const SizedBox(height: 16),
            TextField(
              controller: addController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: '新しいカテゴリ名',
                prefixIcon: const Icon(Icons.add_rounded),
                suffixIcon: IconButton(icon: const Icon(Icons.check_circle_rounded), color: cs.primary, onPressed: addGenre),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => addGenre(),
            ),
          ]),
        );
      }),
    );
  }

  void _pickGenreColor(String genre, StateSetter setModalState) {
    final current = _genreColors[genre];
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('「$genre」の色', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      content: SizedBox(
        width: 320,
        child: Wrap(spacing: 12, runSpacing: 12, children: themeColors.map((c) {
          final selected = current == c.value;
          return GestureDetector(
            onTap: () { setState(() { setModalState(() => _genreColors[genre] = c.value); _saveAllData(); }); Navigator.pop(context); },
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: c, shape: BoxShape.circle,
                border: Border.all(color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.outlineVariant, width: selected ? 3 : 1),
              ),
              child: selected ? Icon(Icons.check_rounded, color: _onColor(c)) : null,
            ),
          );
        }).toList()),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる'))],
    ));
  }

  void _showSettings(bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sheetHandle(),
            const Text('設定', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('ダークモード', style: TextStyle(fontWeight: FontWeight.w700)), secondary: const Icon(Icons.dark_mode_outlined), value: isDark, onChanged: (v) { MyApp.of(context)?.toggleDarkMode(v); Navigator.pop(context); }),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.download_rounded), title: const Text('CSVでエクスポート', style: TextStyle(fontWeight: FontWeight.w700)), onTap: () { _exportToCSV(); Navigator.pop(context); }),
            const Divider(),
            const SizedBox(height: 8),
            Text('テーマカラー', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: themeColors.map((c) => GestureDetector(
              onTap: () { MyApp.of(context)?.changeColor(c); Navigator.pop(context); },
              child: Container(width: 38, height: 38, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: cs.outlineVariant))),
            )).toList()),
          ]),
        ));
      },
    );
  }

  void _deleteSub(int i) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('削除確認'), content: const Text('このサブスクを削除しますか？'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
      TextButton(onPressed: () async { setState(() => _subs.removeAt(i)); await _saveAllData(); Navigator.pop(context); }, child: const Text('削除', style: TextStyle(color: Colors.red)))],
    ));
  }

  Future<void> _openAddScreen({int? index}) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddScreen(editData: index != null ? _subs[index] : null, genres: _genres, genreColors: {for (final g in _genres) g: _getGenreColor(g)})));
    if (result != null) { setState(() { if (index != null) _subs[index] = result; else _subs.add(result); _sortList(); }); _saveAllData(); }
  }
}