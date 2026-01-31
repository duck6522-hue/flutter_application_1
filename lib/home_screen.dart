import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // カンマ用
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
  final _formatter = NumberFormat('#,###'); // カンマ形式の定義

  final List<Color> themeColors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange, 
    Colors.purple, Colors.pink, Colors.blueGrey, Colors.teal, Colors.indigo, Colors.brown
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? subsJson = prefs.getString('subscription_list');
    if (subsJson != null) {
      setState(() {
        _subs = List<Map<String, dynamic>>.from(json.decode(subsJson));
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String subsJson = json.encode(_subs);
    await prefs.setString('subscription_list', subsJson);
  }

  int get _totalPrice {
    return _subs.fold(0, (sum, item) => sum + (item['price'] as int));
  }

  int get _yearlyPrice => _totalPrice * 12;

  Map<String, int> _getGenreTotals() {
    Map<String, int> totals = {};
    for (var item in _subs) {
      String genre = item['genre'] ?? 'その他';
      int price = item['price'] as int;
      totals[genre] = (totals[genre] ?? 0) + price;
    }
    return totals;
  }

  String _getDaysUntil(int payDay) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var nextPayDate = DateTime(now.year, now.month, payDay);
    if (nextPayDate.isBefore(today)) {
      nextPayDate = DateTime(now.year, now.month + 1, payDay);
    }
    final difference = nextPayDate.difference(today).inDays;
    return difference == 0 ? '今日' : 'あと $difference 日';
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color currentColor = Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('サブスク管理', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list), text: '一覧'),
              Tab(icon: Icon(Icons.pie_chart), text: '分析'),
              Tab(icon: Icon(Icons.settings), text: '設定'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildListView(),
            _buildGraphView(),
            _buildSettingsView(isDark, currentColor),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openAddScreen(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _openAddScreen({Map<String, dynamic>? item, int? index}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddScreen(initialData: item)),
    );
    if (result != null && result['name'] != "") {
      setState(() {
        if (index != null) {
          _subs[index] = result;
        } else {
          _subs.add(result);
        }
      });
      _saveData();
    }
  }

  Widget _buildListView() {
    return Column(
      children: [
        _buildTotalCard(),
        Expanded(
          child: _subs.isEmpty 
            ? const Center(child: Text('＋から追加してください'))
            : ListView.builder(
                itemCount: _subs.length,
                itemBuilder: (context, index) {
                  final item = _subs[index];
                  final payDay = item['day'] ?? 1;
                  String genreInitial = (item['genre'] ?? '他').substring(0, 1);
                  String daysText = _getDaysUntil(payDay);
                  
                  return ListTile(
                    onTap: () => _openAddScreen(item: item, index: index),
                    leading: CircleAvatar(child: Text(genreInitial)),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_formatter.format(item['price'])}円'), // カンマ適用
                      ],
                    ),
                    subtitle: Text('${item['genre']} ・ 毎月 $payDay日 ($daysText)'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        setState(() { _subs.removeAt(index); });
                        _saveData();
                      },
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildGraphView() {
    final totals = _getGenreTotals();
    if (totals.isEmpty) return const Center(child: Text('データがありません'));
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text('ジャンル別内訳', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: totals.entries.map((e) {
                  int idx = totals.keys.toList().indexOf(e.key);
                  return PieChartSectionData(
                    color: themeColors[idx % themeColors.length],
                    value: e.value.toDouble(),
                    title: '${e.key}\n${_formatter.format(e.value)}円', // カンマ適用
                    radius: 60,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              children: totals.entries.map((e) {
                int idx = totals.keys.toList().indexOf(e.key);
                return ListTile(
                  leading: Icon(Icons.square, color: themeColors[idx % themeColors.length]),
                  title: Text(e.key),
                  trailing: Text('${_formatter.format(e.value)} 円'), // カンマ適用
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsView(bool isDark, Color currentColor) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const Text('外観の設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('ダークモード'),
          secondary: const Icon(Icons.dark_mode),
          value: isDark,
          onChanged: (bool value) {
            MyApp.of(context)?.toggleDarkMode(value);
          },
        ),
        const Divider(height: 40),
        const Text('テーマカラー', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: themeColors.map((color) {
            bool isSelected = currentColor.toARGB32() == color.toARGB32();
            return InkWell(
              onTap: () => MyApp.of(context)?.changeColor(color),
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(backgroundColor: color, radius: 28),
                  if (isSelected) const Icon(Icons.check, color: Colors.white, size: 30),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('月間合計金額'),
          Text('${_formatter.format(_totalPrice)} 円', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)), // カンマ適用
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          const Text('年間合計（目安）', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text('${_formatter.format(_yearlyPrice)} 円', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // カンマ適用
        ],
      ),
    );
  }
}