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
  String _searchQuery = '';
  String _sortBy = 'date';
  bool _isYearlyView = false;
  final _formatter = NumberFormat('#,###');
  
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
    _loadData();
  }

  // ★テーマに合わせたカッコいい色相を生成する
  List<Color> _generatePalette(Color baseColor, int count) {
    return List.generate(count, (i) {
      double opacity = 1.0 - (i * (0.6 / count));
      return baseColor.withOpacity(opacity.clamp(0.3, 1.0));
    });
  }

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

  IconData _getIcon(String genre) {
    switch (genre) {
      case '動画': return Icons.movie_filter;
      case '音楽': return Icons.music_note_rounded;
      case 'ゲーム': return Icons.sports_esports_rounded;
      case '仕事': return Icons.laptop_mac_rounded;
      case '携帯代': return Icons.stay_current_portrait_rounded;
      case 'クレカ': return Icons.credit_card_rounded;
      case '家賃': return Icons.home_work_rounded;
      case '光熱費': return Icons.bolt_rounded;
      case '保険': return Icons.verified_user_rounded;
      case 'ツール': return Icons.handyman_rounded;
      default: return Icons.account_balance_wallet_rounded;
    }
  }

  int get _totalMonthlyPrice {
    return _subs.fold(0, (sum, item) {
      if (!(item['includeInMonthly'] ?? true)) return sum;
      int price = item['price'] as int;
      return sum + ((item['isYearly'] ?? false) ? (price / 12).round() : price);
    });
  }

  int get _reviewTotalPrice {
    return _subs.fold(0, (sum, item) {
      if (!(item['isReviewing'] ?? false)) return sum;
      int price = item['price'] as int;
      return sum + ((item['isYearly'] ?? false) ? (price / 12).round() : price);
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? subsJson = prefs.getString('subscription_list');
    if (subsJson != null) {
      setState(() {
        _subs = List<Map<String, dynamic>>.from(json.decode(subsJson));
        _sortList();
      });
    }
  }

  void _sortList() {
    setState(() {
      if (_sortBy == 'date') {
        _subs.sort((a, b) {
          int daysA = _calculateDaysUntil(a['month'], a['day'], a['isYearly'] ?? false);
          int daysB = _calculateDaysUntil(b['month'], b['day'], b['isYearly'] ?? false);
          return daysA.compareTo(daysB);
        });
      } else {
        _subs.sort((a, b) => (b['price'] as int).compareTo(a['price'] as int));
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription_list', json.encode(_subs));
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredSubs = _subs.where((sub) => sub['name'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('サブスク管理 Pro', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.0)),
          actions: [
            IconButton(icon: Icon(_sortBy == 'date' ? Icons.sort_rounded : Icons.currency_yen_rounded), onPressed: () { _sortBy = (_sortBy == 'date') ? 'price' : 'date'; _sortList(); }),
            IconButton(icon: const Icon(Icons.tune_rounded), onPressed: () => _showSettings(isDark)),
          ],
          bottom: const TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [Tab(text: '一覧'), Tab(text: '分析レポート')],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMainListTab(filteredSubs),
            _buildAnalysisTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddScreen(),
          icon: const Icon(Icons.add),
          label: const Text('追加', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildMainListTab(List<Map<String, dynamic>> filteredSubs) {
    return Column(
      children: [
        _buildSummaryHeader(),
        _buildToggleSwitch(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'サービス名で検索...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(child: _buildListView(filteredSubs)),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    int displayPrice = _isYearlyView ? _totalMonthlyPrice * 12 : _totalMonthlyPrice;
    int displayReviewPrice = _isYearlyView ? _reviewTotalPrice * 12 : _reviewTotalPrice;
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isYearlyView ? '年間支出合計' : '月間支出合計', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${_formatter.format(displayPrice)} 円', style: const TextStyle(fontSize: 34, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -1)),
              ]),
              Icon(Icons.auto_graph_rounded, color: Colors.white.withOpacity(0.4), size: 48),
            ],
          ),
          if (displayReviewPrice > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 8),
                  Text('解約検討中の節約可能額: ', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${_formatter.format(displayReviewPrice)} 円', style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<bool>(
        style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
        segments: const [
          ButtonSegment(
            value: false, 
            label: Text('月額表示'), 
            icon: Icon(Icons.calendar_month_rounded)
          ),
          ButtonSegment(
            value: true, 
            label: Text('年額表示'), 
            icon: Icon(Icons.event_note_rounded)
          ),
        ], // ここでリストを閉じる ] が重要！
        selected: <bool>{_isYearlyView},
        onSelectionChanged: (Set<bool> newSelection) => setState(() => _isYearlyView = newSelection.first),
      ),
    );
  }
  
  Widget _buildListView(List<Map<String, dynamic>> displayList) {
    if (displayList.isEmpty) return const Center(child: Text('データがありません', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final item = displayList[index];
        bool isYearly = item['isYearly'] ?? false;
        bool include = item['includeInMonthly'] ?? true;
        bool reviewing = item['isReviewing'] ?? false;
        int diff = _calculateDaysUntil(item['month'], item['day'], isYearly);
        
        int itemPrice = item['price'] as int;
        if (!_isYearlyView && isYearly) itemPrice = (itemPrice / 12).round();
        if (_isYearlyView && !isYearly) itemPrice = itemPrice * 12;

        return Card(
          elevation: 0,
          color: reviewing ? Colors.orange.withOpacity(0.08) : (include ? Theme.of(context).colorScheme.surfaceContainerLow : Colors.grey.withOpacity(0.05)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: reviewing ? Colors.orange.withOpacity(0.3) : Colors.transparent)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (reviewing ? Colors.orange : (include ? Theme.of(context).colorScheme.primary : Colors.grey)).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(_getIcon(item['genre']), color: reviewing ? Colors.orange : (include ? Theme.of(context).colorScheme.primary : Colors.grey)),
            ),
            title: Row(
              children: [
                Expanded(child: Text(item['name'], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, decoration: include ? null : TextDecoration.lineThrough, color: include ? null : Colors.grey))),
                if (reviewing) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)),
                  child: const Text('検討中', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            subtitle: Text(isYearly ? '${item['month']}月${item['day']}日（あと $diff日）' : '毎月 ${item['day']}日（あと $diff日）', style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${_formatter.format(itemPrice)}円', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: include ? null : Colors.grey, letterSpacing: -0.5)),
                  Text(_isYearlyView ? '年額' : '月額', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.chevron_right_rounded, color: Colors.grey), onPressed: () => _openAddScreen(index: _subs.indexOf(item))),
              ],
            ),
            onTap: () => _openAddScreen(index: _subs.indexOf(item)),
            onLongPress: () => _deleteSub(_subs.indexOf(item)),
          ),
        );
      },
    );
  }

  void _deleteSub(int index) {
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('削除しますか？', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Text('「${_subs[index]['name']}」をリストから削除します。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        ElevatedButton(onPressed: () async { setState(() => _subs.removeAt(index)); await _saveData(); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red), child: const Text('削除')),
      ],
    ));
  }

  Widget _buildAnalysisTab() {
    Map<String, int> totals = {};
    for (var item in _subs) {
      if (!(item['includeInMonthly'] ?? true)) continue;
      int price = item['price'] as int;
      int monthlyPrice = (item['isYearly'] ?? false) ? (price / 12).round() : price;
      int displayPrice = _isYearlyView ? monthlyPrice * 12 : monthlyPrice;
      totals[item['genre']] = (totals[item['genre']] ?? 0) + displayPrice;
    }
    
    if (totals.isEmpty) return const Center(child: Text('分析データがありません'));
    
    final Color primary = Theme.of(context).colorScheme.primary;
    final List<Color> graphColors = _generatePalette(primary, totals.length);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(_isYearlyView ? '年間支出カテゴリー内訳' : '月間支出カテゴリー内訳', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 32),
          
          SizedBox(height: 280, child: PieChart(PieChartData(
            startDegreeOffset: 270,
            centerSpaceRadius: 60,
            sectionsSpace: 4,
            sections: totals.entries.map((e) {
              int idx = totals.keys.toList().indexOf(e.key);
              return PieChartSectionData(
                color: graphColors[idx % graphColors.length],
                value: e.value.toDouble(),
                title: '${(e.value / (_isYearlyView ? _totalMonthlyPrice * 12 : _totalMonthlyPrice) * 100).toStringAsFixed(1)}%',
                radius: 75,
                titleStyle: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w900),
              );
            }).toList(),
          ))),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 12, runSpacing: 12,
              children: totals.entries.map((e) {
                int idx = totals.keys.toList().indexOf(e.key);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: graphColors[idx % graphColors.length].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: graphColors[idx % graphColors.length].withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: graphColors[idx % graphColors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      Text('${_formatter.format(e.value)}円', style: TextStyle(color: graphColors[idx % graphColors.length], fontWeight: FontWeight.w900)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  void _showSettings(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('カスタマイズ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            SwitchListTile(title: const Text('ダークモード', style: TextStyle(fontWeight: FontWeight.bold)), secondary: const Icon(Icons.dark_mode_rounded), value: isDark, onChanged: (bool value) { MyApp.of(context)?.toggleDarkMode(value); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.file_download_rounded), title: const Text('CSVデータを書き出し', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Excel等で管理可能なファイルを作成します'), onTap: () { _exportToCSV(); Navigator.pop(context); }),
            const Divider(height: 40),
            const Text('テーマカラー', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: themeColors.map((color) => GestureDetector(
                onTap: () { MyApp.of(context)?.changeColor(color); Navigator.pop(context); },
                child: Container(
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))]),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddScreen({int? index}) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddScreen(editData: index != null ? _subs[index] : null)));
    if (result != null) { setState(() { if (index != null) _subs[index] = result; else _subs.add(result); _sortList(); }); _saveData(); }
  }
}