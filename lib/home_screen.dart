import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'add_screen.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _subs = [];
  List<String> _genres = ['動画', '音楽', '携帯代', '家賃', 'その他'];
  Map<String, int> _genreColors = {};
  String _searchQuery = '';
  String _sortBy = 'date';
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
      _genres = List<String>.from(json.decode(prefs.getString('genre_list') ?? '["動画", "音楽", "携帯代", "家賃", "その他"]'));
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
  Color _getGenreColor(String genre) {
    if (_genreColors.containsKey(genre)) return Color(_genreColors[genre]!);
    return Colors.grey.shade400;
  }

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
    final filteredSubs = _subs.where((sub) => sub['name'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('サブスク管理 Pro', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1)),
          actions: [
            IconButton(icon: const Icon(Icons.category_rounded), onPressed: _showGenreManagement),
            IconButton(icon: const Icon(Icons.tune_rounded), onPressed: () => _showSettings(isDark)),
          ],
          bottom: const TabBar(tabs: [Tab(text: '一覧'), Tab(text: '分析')]),
        ),
        body: TabBarView(
          children: [
            Column(children: [
              _buildSummaryHeader(),
              _buildToggleSwitch(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'サービス名で検索...', prefixIcon: const Icon(Icons.search),
                    filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              Expanded(child: _buildListView(filteredSubs)),
            ]),
            _buildAnalysisTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddScreen(),
          label: const Text('追加', style: TextStyle(fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    int displayPrice = _isYearlyView ? _totalMonthlyPrice * 12 : _totalMonthlyPrice;
    int displayReviewPrice = _isYearlyView ? _reviewTotalPrice * 12 : _reviewTotalPrice;
    return Container(
      padding: const EdgeInsets.all(24), margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 10)],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isYearlyView ? '計上対象の年額' : '計上対象の月額', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            Text('${_formatter.format(displayPrice)} 円', style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w900)),
          ]),
          const Icon(Icons.auto_graph_rounded, color: Colors.white30, size: 48),
        ]),
        if (displayReviewPrice > 0) ...[
          const Divider(color: Colors.white24, height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('検討中サービスの合計:', style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            Text('- ${_formatter.format(displayReviewPrice)} 円', style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.w900)),
          ]),
        ]
      ]),
    );
  }

  Widget _buildToggleSwitch() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('月額'), icon: Icon(Icons.calendar_month)),
        ButtonSegment(value: true, label: Text('年額'), icon: Icon(Icons.event_note)),
      ],
      selected: <bool>{_isYearlyView},
      onSelectionChanged: (set) => setState(() => _isYearlyView = set.first),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> list) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        bool include = item['includeInMonthly'] ?? true;
        bool reviewing = item['isReviewing'] ?? false;
        int diff = _calculateDaysUntil(item['month'], item['day'], item['isYearly'] ?? false);
        int itemPrice = _isYearlyView ? (item['isYearly'] ? item['price'] : item['price'] * 12) : (item['isYearly'] ? (item['price'] / 12).round() : item['price']);

        return Card(
          elevation: 0, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: reviewing ? Colors.orange.withOpacity(0.1) : (include ? Theme.of(context).colorScheme.surfaceContainerLow : Colors.grey.withOpacity(0.1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: reviewing ? Colors.orange : Colors.transparent)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: _getGenreColor(item['genre']), child: const Icon(Icons.star, size: 14, color: Colors.white)),
            title: Text(item['name'], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, decoration: include ? null : TextDecoration.lineThrough, color: include ? null : Colors.grey)),
            subtitle: Text('あと $diff日${reviewing ? " (⚠️検討中)" : ""}'),
            trailing: Text('${_formatter.format(itemPrice)}円', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            onTap: () => _openAddScreen(index: _subs.indexOf(item)),
            onLongPress: () => _deleteSub(_subs.indexOf(item)),
          ),
        );
      },
    );
  }

  Widget _buildAnalysisTab() {
    Map<String, int> totals = {};
    for (var item in _subs) {
      if (!(item['includeInMonthly'] ?? true)) continue;
      int p = (item['isYearly'] ?? false) ? (item['price'] / 12).round() : item['price'] as int;
      totals[item['genre']] = (totals[item['genre']] ?? 0) + (_isYearlyView ? p * 12 : p);
    }
    if (totals.isEmpty) return const Center(child: Text('データがありません'));

    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 30),
        SizedBox(height: 280, child: PieChart(PieChartData(
          startDegreeOffset: 270, sectionsSpace: 4, centerSpaceRadius: 60,
          sections: totals.entries.map((e) => PieChartSectionData(
            color: _getGenreColor(e.key), value: e.value.toDouble(), radius: 70,
            title: '${(e.value / (_isYearlyView ? _totalMonthlyPrice * 12 : _totalMonthlyPrice) * 100).toStringAsFixed(1)}%',
            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          )).toList(),
        ))),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Wrap(spacing: 12, runSpacing: 12, children: totals.keys.map((g) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: _getGenreColor(g).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _getGenreColor(g).withOpacity(0.5))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 5, backgroundColor: _getGenreColor(g)),
              const SizedBox(width: 8),
              Text('$g: ${_formatter.format(totals[g])}円', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          )).toList()),
        ),
      ]),
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
          const Text('カテゴリと色', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Expanded(child: ListView.builder(
            itemCount: _genres.length,
            itemBuilder: (context, i) => ListTile(
              leading: GestureDetector(
                onTap: () => _pickGenreColor(_genres[i], setModalState),
                child: CircleAvatar(backgroundColor: _getGenreColor(_genres[i]), child: const Icon(Icons.palette, size: 14, color: Colors.white)),
              ),
              title: Text(_genres[i], style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () {
                setState(() { setModalState(() => _genres.removeAt(i)); _saveAllData(); });
              }),
            ),
          )),
          TextField(
            decoration: const InputDecoration(hintText: 'カテゴリを追加...', suffixIcon: Icon(Icons.add)),
            onSubmitted: (val) { if (val.isNotEmpty) setState(() { setModalState(() => _genres.add(val)); _saveAllData(); }); },
          ),
        ]),
      )),
    );
  }

  void _pickGenreColor(String genre, StateSetter setModalState) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text('$genre の色'),
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
        ListTile(leading: const Icon(Icons.download), title: const Text('CSV保存'), onTap: () { _exportToCSV(); Navigator.pop(context); }),
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