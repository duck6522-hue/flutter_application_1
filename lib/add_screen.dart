import 'package:flutter/material.dart';

class AddScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const AddScreen({super.key, this.initialData});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _genreController;
  late TextEditingController _dayController;

  // 人気サービスのリスト
  final List<Map<String, dynamic>> popularServices = [
    {'name': 'Netflix', 'price': 1490, 'genre': 'エンタメ'},
    {'name': 'YouTube Premium', 'price': 1280, 'genre': 'エンタメ'},
    {'name': 'Amazon Prime', 'price': 600, 'genre': '生活'},
    {'name': 'Apple Music', 'price': 1080, 'genre': 'エンタメ'},
    {'name': 'ChatGPT Plus', 'price': 3000, 'genre': '仕事'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData?['name'] ?? '');
    _priceController = TextEditingController(text: widget.initialData?['price']?.toString() ?? '');
    _genreController = TextEditingController(text: widget.initialData?['genre'] ?? '');
    _dayController = TextEditingController(text: widget.initialData?['day']?.toString() ?? '1');
  }

  void _setPopularService(Map<String, dynamic> service) {
    setState(() {
      _nameController.text = service['name'];
      _priceController.text = service['price'].toString();
      _genreController.text = service['genre'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('サブスクを追加')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('人気サービス', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: popularServices.map((s) => ActionChip(
                label: Text(s['name']),
                onPressed: () => _setPopularService(s),
              )).toList(),
            ),
            const Divider(height: 40),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'サービス名')),
            TextField(controller: _genreController, decoration: const InputDecoration(labelText: 'ジャンル')),
            TextField(controller: _dayController, decoration: const InputDecoration(labelText: '支払日（1〜31）'), keyboardType: TextInputType.number),
            TextField(controller: _priceController, decoration: const InputDecoration(labelText: '価格（円）'), keyboardType: TextInputType.number),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () {
                Navigator.pop(context, {
                  'name': _nameController.text,
                  'price': int.tryParse(_priceController.text) ?? 0,
                  'genre': _genreController.text,
                  'day': int.tryParse(_dayController.text) ?? 1,
                });
              },
              child: const Text('保存する'),
            ),
          ],
        ),
      ),
    );
  }
}