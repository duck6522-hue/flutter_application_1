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

  // ★重要：次の支払日までの日数を計算するロジック
  int _calculateDaysUntil(int? month, int day, bool isYearly) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    DateTime nextDate;
    if (isYearly && month != null) {
      nextDate = DateTime(now.year, month, day);
      if (nextDate.isBefore(today)) {
        nextDate = DateTime(now.year + 1, month, day);
      }
    } else {
      nextDate = DateTime(now.year, now.month, day);
      if (nextDate.isBefore(today)) {
        nextDate = DateTime(now.year, now.month + 1, day);
      }
    }
    return nextDate.difference(today).inDays;
  }

  int get _totalMonthlyPrice {
    return _subs.fold(0, (sum, item) {
      int price = item['price'] as int;
      bool itemIsYearly = item['isYearly'] ?? false;
      return sum + (itemIsYearly ? (price / 12).round() : price);
    });
  }

  IconData _getIcon(String genre) {
    if (genre.contains('動画')) return Icons.movie;
    if (genre.contains('音楽')) return Icons.music_note;
    if (genre.contains('ゲーム')) return Icons.videogame_asset;
    if (genre.contains('仕事')) return Icons.build;
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
          title: const Text('サブスク管理 Pro', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: Icon(_sortBy == 'date' ? Icons.calendar_today : Icons.currency_yen),
              onPressed: () {
                _sortBy = (_sortBy == 'date') ? 'price' : 'date';
                _sortList();
              },
            ),
            IconButton(icon: const Icon(Icons.settings), onPressed: () => _showSettings(isDark)),
          ],
          bottom: const TabBar(tabs: [Tab(text: '一覧'), Tab(text: '分析・グラフ')]),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                _buildSummaryHeader(),
                _buildToggleSwitch(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openAddScreen(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('月額換算'), icon: Icon(Icons.calendar_month)),
          ButtonSegment(value: true, label: Text('年額換算'), icon: Icon(Icons.event_note)),
        ],
        selected: {_isYearlyView},
        onSelectionChanged: (Set<bool> newSelection) {
          setState(() => _isYearlyView = newSelection.first);
        },
      ),
    );
  }

  Widget _buildSummaryHeader() {
    int displayPrice = _isYearlyView ? _totalMonthlyPrice * 12 : _totalMonthlyPrice;
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isYearlyView ? '年間支出（換算）' : '月間支出（換算）', style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Text('${_formatter.format(displayPrice)} 円', 
              style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
          const Icon(Icons.account_balance_wallet, color: Colors.white30, size: 48),
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
        bool itemIsYearly = item['isYearly'] ?? false;
        int diff = _calculateDaysUntil(item['month'], item['day'], itemIsYearly);
        
        int itemPrice = item['price'] as int;
        if (!_isYearlyView && itemIsYearly) itemPrice = (itemPrice / 12).round();
        if (_isYearlyView && !itemIsYearly) itemPrice = itemPrice * 12;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: Icon(_getIcon(item['genre']), color: Theme.of(context).colorScheme.primary),
            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(itemIsYearly 
              ? '次回の更新: ${item['month']}月${item['day']}日（あと $diff日）' 
              : '毎月 ${item['day']}日（あと $diff日）'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${_formatter.format(itemPrice)}円', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(_isYearlyView ? '年額相当' : '月額相当', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteSub(_subs.indexOf(item)),
                ),
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
    for (var item in _subs) {
      int price = item['price'] as int;
      bool itemIsYearly = item['isYearly'] ?? false;
      int monthlyPrice = itemIsYearly ? (price / 12).round() : price;
      int displayPrice = _isYearlyView ? monthlyPrice * 12 : monthlyPrice;
      totals[item['genre']] = (totals[item['genre']] ?? 0) + displayPrice;
    }
    if (totals.isEmpty) return const Center(child: Text('データがありません'));
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(_isYearlyView ? '年間支出の内訳' : '月間支出の内訳', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        SizedBox(
          height: 300,
          child: PieChart(PieChartData(
            centerSpaceRadius: 50,
            sections: totals.entries.map((e) => PieChartSectionData(
              color: themeColors[totals.keys.toList().indexOf(e.key) % themeColors.length],
              value: e.value.toDouble(),
              title: '${e.key}\n${_formatter.format(e.value)}円',
              radius: 80,
              titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
            )).toList(),
          )),
        ),
      ],
    );
  }

  void _showSettings(bool isDark) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('設定', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('ダークモード'),
              secondary: const Icon(Icons.dark_mode),
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
              height: 150,
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