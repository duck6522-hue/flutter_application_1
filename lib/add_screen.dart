import 'package:flutter/material.dart';

class AddScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;
  const AddScreen({super.key, this.editData});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  int _selectedMonth = 1; // ★追加：更新月
  int _selectedDay = 1;
  String _selectedGenre = '動画';
  bool _isYearly = false;

  final List<String> _genres = ['動画', '音楽', 'ゲーム', '仕事', 'ツール', 'その他'];

  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      _nameController.text = widget.editData!['name'];
      _priceController.text = widget.editData!['price'].toString();
      _selectedMonth = widget.editData!['month'] ?? 1; // ★追加
      _selectedDay = widget.editData!['day'];
      _selectedGenre = widget.editData!['genre'];
      _isYearly = widget.editData!['isYearly'] ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editData == null ? 'サブスクを追加' : '編集')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'サービス名')),
          const SizedBox(height: 20),
          TextField(controller: _priceController, decoration: const InputDecoration(labelText: '金額'), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          
          const Text('支払いサイクル', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              ChoiceChip(label: const Text('月払い'), selected: !_isYearly, onSelected: (val) => setState(() => _isYearly = false)),
              const SizedBox(width: 10),
              ChoiceChip(label: const Text('年払い'), selected: _isYearly, onSelected: (val) => setState(() => _isYearly = true)),
            ],
          ),
          const SizedBox(height: 20),

          // ★追加：年払いの時だけ「月」の選択肢を出す
          if (_isYearly) ...[
            const Text('更新月', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<int>(
              value: _selectedMonth,
              items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}月'))),
              onChanged: (val) => setState(() => _selectedMonth = val!),
            ),
            const SizedBox(height: 20),
          ],

          Text(_isYearly ? '更新日' : '支払日 (毎月)', style: const TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<int>(
            value: _selectedDay,
            items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}日'))),
            onChanged: (val) => setState(() => _selectedDay = val!),
          ),
          const SizedBox(height: 20),
          
          const Text('ジャンル', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: _genres.map((g) => ChoiceChip(
              label: Text(g),
              selected: _selectedGenre == g,
              onSelected: (val) => setState(() => _selectedGenre = g),
            )).toList(),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': _nameController.text,
                'price': int.parse(_priceController.text),
                'month': _selectedMonth, // ★追加
                'day': _selectedDay,
                'genre': _selectedGenre,
                'isYearly': _isYearly,
              });
            },
            child: const Text('保存する'),
          ),
        ],
      ),
    );
  }
}