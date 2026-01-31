import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart'; // ★ 円グラフに必須
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
  final _formatter = NumberFormat('#,###');

  final List<Color> themeColors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange, 
    Colors.purple, Colors.pink, Colors.blueGrey, Colors.teal, Colors.indigo, Colors.brown
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 支払日までの日数を計算して並べ替える
  int _calculateDaysUntil(int payDay) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var nextPayDate = DateTime(now.year, now.month, payDay);
    if (nextPayDate.isBefore(today)) nextPayDate = DateTime(now.year, now.month + 1, payDay);
    return nextPayDate.difference(today).inDays;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? subsJson = prefs.getString('subscription_list');
    if (subsJson != null) {
      setState(() {
        _subs = List<Map<String, dynamic>>.from(json.decode(subsJson));
        _subs.sort((a, b) => _calculateDaysUntil(a['day'] ?? 1).compareTo(_calculateDaysUntil(b['day'] ?? 1)));
      });
    }
  }

  // グラフ用の計算
  Map<String, int> _getGenreTotals() {
    Map<String, int> totals = {};
    for (var item in _subs) {
      String genre = item['genre'] ?? 'その他';
      int price = item['price'] as int;
      totals[genre] = (totals[genre] ?? 0) + price;
    }
    return totals;
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
          bottom: const TabBar(
            tabs: [Tab(text: '一覧'), Tab(text: '分析'), Tab(text: '設定')],
          ),
        ),
        body: TabBarView(
          children: [
            _buildListView(),
            _buildGraphView(), // ★グラフ
            _buildSettingsView(isDark, currentColor), // ★設定
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openAddScreen(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // --- グラフ画面の作成 ---
  Widget _buildGraphView() {
    final totals = _getGenreTotals();
    if (totals.isEmpty) return const Center(child: Text('データを追加してください'));
    return Column(
      children: [
        const SizedBox(height: 30),
        SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sections: totals.entries.map((e) {
                int idx = totals.keys.toList().indexOf(e.key);
                return PieChartSectionData(
                  color: themeColors[idx % themeColors.length],
                  value: e.value.toDouble(),
                  title: '${e.key}\n${e.value}円',
                  radius: 70,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // --- 設定画面（カラー変更） ---
  Widget _buildSettingsView(bool isDark, Color currentColor) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('テーマカラーを選択', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 15,
          runSpacing: 15,
          children: themeColors.map((color) {
            return GestureDetector(
              onTap: () => MyApp.of(context)?.changeColor(color), // ★ここで色を変える
              child: CircleAvatar(
                backgroundColor: color,
                radius: 25,
                child: currentColor.toARGB32() == color.toARGB32() ? const Icon(Icons.check, color: Colors.white) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // (リスト表示などの部分は省略しましたが、全体の動作に影響しないよう前のコードを維持してください)
  Widget _buildListView() {
    return _subs.isEmpty 
      ? const Center(child: Text('＋ボタンで追加してください'))
      : ListView.builder(
          itemCount: _subs.length,
          itemBuilder: (context, index) {
            final item = _subs[index];
            return ListTile(
              title: Text(item['name']),
              subtitle: Text('${item['genre']} / ${_formatter.format(item['price'])}円'),
            );
          },
        );
  }

  Future<void> _openAddScreen() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddScreen()));
    if (result != null) _loadData();
  }
}