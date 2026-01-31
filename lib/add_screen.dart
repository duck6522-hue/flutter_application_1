import 'package:flutter/material.dart';

class AddScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;
  const AddScreen({super.key, this.editData});
  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _genreController;
  late TextEditingController _dayController;

  final List<Map<String, dynamic>> popularServices = [
    {'name': 'Netflix', 'price': 1490, 'genre': 'エンタメ'},
    {'name': 'YouTube Premium', 'price': 1280, 'genre': 'エンタメ'},
    {'name': 'Amazon Prime', 'price': 600, 'genre': '生活'},
    {'name': 'Apple Music', 'price': 1080, 'genre': 'エンタメ'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editData?['name'] ?? '');
    _priceController = TextEditingController(text: widget.editData?['price']?.toString() ?? '');
    _genreController = TextEditingController(text: widget.editData?['genre'] ?? '');
    _dayController = TextEditingController(text: widget.editData?['day']?.toString() ?? '1');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editData != null ? '編集' : 'サブスクを追加')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.editData == null) ...[
              const Text('人気サービス', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: popularServices.map((s) => ActionChip(
                  label: Text(s['name']),
                  onPressed: () {
                    _nameController.text = s['name'];
                    _priceController.text = s['price'].toString();
                    _genreController.text = s['genre'];
                  },
                )).toList(),
              ),
              const Divider(height: 40),
            ],
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'サービス名')),
            TextField(controller: _genreController, decoration: const InputDecoration(labelText: 'ジャンル')),
            TextField(controller: _dayController, decoration: const InputDecoration(labelText: '支払日（1-31）'), keyboardType: TextInputType.number),
            TextField(controller: _priceController, decoration: const InputDecoration(labelText: '価格（円）'), keyboardType: TextInputType.number),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () {
                Navigator.pop(context, {
                  'name': _nameController.text,
                  'genre': _genreController.text,
                  'day': int.tryParse(_dayController.text) ?? 1,
                  'price': int.tryParse(_priceController.text) ?? 0,
                });
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}