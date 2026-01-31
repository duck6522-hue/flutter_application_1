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
  final _formatter = NumberFormat('#,###');
  final List<Color> themeColors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.pink, Colors.teal];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

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

  int get _totalPrice => _subs.fold(0, (sum, item) => sum + (item['price'] as int));

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('サブスク管理', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [Tab(text: '一覧'), Tab(text: '分析'), Tab(text: '設定')],
          ),
        ),
        body: TabBarView(
          children: [_buildListView(), _buildGraphView(), _buildSettingsView(isDark)],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddScreen()));
            if (result != null) {
              setState(() { _subs.add(result); });
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('subscription_list', json.encode(_subs));
              _loadData();
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        _buildTotalCard(),
        Expanded(
          child: _subs.isEmpty 
            ? const Center(child: Text('＋で追加してください'))
            : ListView.builder(
                itemCount: _subs.length,
                itemBuilder: (context, index) {
                  final item = _subs[index];
                  int diff = _calculateDaysUntil(item['day'] ?? 1);
                  return ListTile(
                    leading: CircleAvatar(child: Text(item['genre'].substring(0, 1))),
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('毎月 ${item['day']}日（あと $diff日）'),
                    trailing: Text('${_formatter.format(item['price'])}円'),
                  );
                },
              ),
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
          Text('${_formatter.format(_totalPrice)} 円', 
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _buildGraphView() {
    Map<String, int> totals = {};
    for (var item in _subs) {
      totals[item['genre']] = (totals[item['genre']] ?? 0) + (item['price'] as int);
    }
    if (totals.isEmpty) return const Center(child: Text('データがありません'));
    return Column(
      children: [
        const SizedBox(height: 30),
        SizedBox(height: 200, child: PieChart(PieChartData(
          sections: totals.entries.map((e) => PieChartSectionData(
            color: themeColors[totals.keys.toList().indexOf(e.key) % themeColors.length],
            value: e.value.toDouble(),
            title: '${e.key}\n${e.value}円',
            radius: 60,
            titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
          )).toList(),
        ))),
      ],
    );
  }

  Widget _buildSettingsView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ★ ダークモードのスイッチを復活！
        SwitchListTile(
          title: const Text('ダークモード'),
          secondary: const Icon(Icons.dark_mode),
          value: isDark,
          onChanged: (bool value) => MyApp.of(context)?.toggleDarkMode(value),
        ),
        const Divider(height: 40),
        const Text('テーマカラー', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 15,
          runSpacing: 15,
          children: themeColors.map((color) => GestureDetector(
            onTap: () => MyApp.of(context)?.changeColor(color),
            child: CircleAvatar(backgroundColor: color, radius: 25),
          )).toList(),
        ),
      ],
    );
  }
}