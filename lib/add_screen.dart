import 'package:flutter/material.dart';

class AddScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;
  final List<String> genres; // ホームからカテゴリリストを受け取る
  const AddScreen({super.key, this.editData, required this.genres});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  int _selectedMonth = 1;
  int _selectedDay = 1;
  late String _selectedGenre;
  bool _isYearly = false;
  bool _includeInMonthly = true;
  bool _isReviewing = false;

  @override
  void initState() {
    super.initState();
    _selectedGenre = widget.genres.first; // 初期値をリストの最初に設定
    if (widget.editData != null) {
      _nameController.text = widget.editData!['name'];
      _priceController.text = widget.editData!['price'].toString();
      _selectedMonth = widget.editData!['month'] ?? 1;
      _selectedDay = widget.editData!['day'];
      _selectedGenre = widget.editData!['genre'];
      _isYearly = widget.editData!['isYearly'] ?? false;
      _includeInMonthly = widget.editData!['includeInMonthly'] ?? true;
      _isReviewing = widget.editData!['isReviewing'] ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editData == null ? 'サブスクを追加' : '編集')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'サービス名', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          TextField(controller: _priceController, decoration: const InputDecoration(labelText: '金額', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          
          SwitchListTile(title: const Text('合計に含める'), value: _includeInMonthly, onChanged: (v) => setState(() => _includeInMonthly = v)),
          SwitchListTile(title: const Text('解約を検討中'), activeColor: Colors.orange, value: _isReviewing, onChanged: (v) => setState(() => _isReviewing = v)),
          const Divider(),

          const Text('サイクル', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            ChoiceChip(label: const Text('月払い'), selected: !_isYearly, onSelected: (v) => setState(() => _isYearly = false)),
            const SizedBox(width: 10),
            ChoiceChip(label: const Text('年払い'), selected: _isYearly, onSelected: (v) => setState(() => _isYearly = true)),
          ]),
          const SizedBox(height: 20),

          if (_isYearly) ...[
            DropdownButton<int>(value: _selectedMonth, items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}月'))), onChanged: (v) => setState(() => _selectedMonth = v!)),
          ],
          DropdownButton<int>(value: _selectedDay, items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}日'))), onChanged: (v) => setState(() => _selectedDay = v!)),
          const SizedBox(height: 20),
          
          const Text('カテゴリ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: widget.genres.map((g) => ChoiceChip(label: Text(g), selected: _selectedGenre == g, onSelected: (v) => setState(() => _selectedGenre = g))).toList()),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'name': _nameController.text, 'price': int.parse(_priceController.text),
              'month': _selectedMonth, 'day': _selectedDay, 'genre': _selectedGenre,
              'isYearly': _isYearly, 'includeInMonthly': _includeInMonthly, 'isReviewing': _isReviewing,
            }),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}