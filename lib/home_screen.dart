import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
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
  String _sortBy = 'date'; // 'date' or 'price'
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

  // 残り日数の計算
  int _calculateDaysUntil(int payDay) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var nextPayDate = DateTime(now.year, now.month, payDay);
    if (nextPayDate.isBefore(today)) nextPayDate = DateTime(now.year, now.month + 1, payDay);
    return nextPayDate.difference(today).inDays;
  }

  // ジャンルに応じたアイコンを返す
  IconData _getIcon(String genre) {
    if (genre.contains('動画') || genre.contains('映画')) return Icons.movie;
    if (genre.contains('音楽')) return Icons.music_note;
    if (genre.contains('ゲーム')) return Icons.videogame_asset;
    if (genre.contains('仕事') || genre.contains('ツール')) return Icons.build;
    return Icons.subscriptions;
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
        _subs.sort((a, b) => _calculateDaysUntil(a['day'] ?? 1).compareTo(_calculateDaysUntil(b['day'] ?? 1)));
      } else {
        _subs.sort((a, b) => (b['price'] as int).compareTo(a['price'] as int));
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription_list', json.encode(_subs));
  }

  int get _totalPrice => _subs.fold(0, (sum, item) => sum + (item['price'] as int));

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    // 検索フィルタリング
    final filteredSubs = _subs.where((sub) => sub['name'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('サブスク管理 Pro', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: Icon(_sortBy == 'date' ? Icons.calendar_today : Icons.currency_yen),
              onPressed: () {
                _sortBy = (_sortBy == 'date') ? 'price' : 'date';
                _sortList();
              },
              tooltip: '並び替え切り替え',
            ),
            IconButton(icon: const Icon(Icons.settings), onPressed: () => _showSettings(isDark)),
          ],
          bottom: const TabBar(tabs: [Tab(text: '一覧・分析'), Tab(text: 'グラフ')]),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                _buildSummaryHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: const InputDecoration(hintText: '名前で検索...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                Expanded(child: _buildListView(filteredSubs)),
              ],
            ),
            _buildGraphView(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddScreen(),
          label: const Text('追加'),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('月額合計', style: TextStyle(color: Colors.white70)),
            Text('${_formatter.format(_totalPrice)} 円', style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('年間推定', style: TextStyle(color: Colors.white70)),
            Text('${_formatter.format(_totalPrice * 12)} 円', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500)),
          ]),
        ],
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> displayList) {
    if (displayList.isEmpty) return const Center(child: Text('データが見つかりません'));
    return ListView.builder(
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final item = displayList[index];
        int diff = _calculateDaysUntil(item['day'] ?? 1);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: Icon(_getIcon(item['genre']), color: Theme.of(context).colorScheme.primary),
            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('毎月 ${item['day']}日（あと $diff日）'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_formatter.format(item['price'])}円', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteSub(_subs.indexOf(item))),
              ],
            ),
            onTap: () => _openAddScreen(index: _subs.indexOf(item)),
          ),
        );
      },
    );
  }

  void _deleteSub(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${_subs[index]['name']}」を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(onPressed: () async {
            setState(() => _subs.removeAt(index));
            await _saveData();
            Navigator.pop(context);
          }, child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildGraphView() {
    Map<String, int> totals = {};
    for (var item in _subs) totals[item['genre']] = (totals[item['genre']] ?? 0) + (item['price'] as int);
    if (totals.isEmpty) return const Center(child: Text('データがありません'));
    return PieChart(PieChartData(
      centerSpaceRadius: 50,
      sections: totals.entries.map((e) => PieChartSectionData(
        color: themeColors[totals.keys.toList().indexOf(e.key) % themeColors.length],
        value: e.value.toDouble(),
        title: '${e.key}\n${e.value}円',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
      )).toList(),
    ));
  }

  void _showSettings(bool isDark) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('ダークモード'),
              value: isDark,
              onChanged: (bool value) {
                MyApp.of(context)?.toggleDarkMode(value);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            const Text('テーマカラーを選択'),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: GridView.count(
                crossAxisCount: 7,
                children: themeColors.map((color) => GestureDetector(
                  onTap: () {
                    MyApp.of(context)?.changeColor(color);
                    Navigator.pop(context);
                  },
                  child: Padding(padding: const EdgeInsets.all(4), child: CircleAvatar(backgroundColor: color)),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddScreen({int? index}) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddScreen(editData: index != null ? _subs[index] : null)));
    if (result != null) {
      setState(() {
        if (index != null) _subs[index] = result;
        else _subs.add(result);
        _sortList();
      });
      _saveData();
    }
  }
}