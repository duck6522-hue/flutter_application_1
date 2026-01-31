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
  final _memoController = TextEditingController();

  // ★ 人気のサブスクリスト（ここを増やすとさらに便利になります！）
  final List<Map<String, dynamic>> popularServices = [
    {'name': 'Netflix', 'price': 1490, 'genre': 'エンタメ'},
    {'name': 'YouTube Premium', 'price': 1280, 'genre': 'エンタメ'},
    {'name': 'Amazon Prime', 'price': 600, 'genre': '生活'},
    {'name': 'Apple Music', 'price': 1080, 'genre': 'エンタメ'},
    {'name': 'ChatGPT Plus', 'price': 3000, 'genre': '仕事'},
    {'name': 'Disney+', 'price': 990, 'genre': 'エンタメ'},
    {'name': 'U-NEXT', 'price': 2189, 'genre': 'エンタメ'},
    {'name': 'Nintendo Online', 'price': 306, 'genre': 'エンタメ'},
  ];

  final List<String> genreSamples = ['エンタメ', '仕事', '生活', '教育', 'その他'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData?['name'] ?? '');
    _priceController = TextEditingController(text: widget.initialData?['price']?.toString() ?? '');
    _genreController = TextEditingController(text: widget.initialData?['genre'] ?? '');
    _dayController = TextEditingController(text: widget.initialData?['day']?.toString() ?? '');
  }

  // 人気リストからポチッと入力する関数
  void _setPopularService(Map<String, dynamic> service) {
    setState(() {
      _nameController.text = service['name'];
      _priceController.text = service['price'].toString();
      _genreController.text = service['genre'];
    });
  }

  void _parseMemo() {
    final text = _memoController.text;
    final lines = text.split('\n');
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      final priceMatch = RegExp(r'\d+').firstMatch(line);
      final price = priceMatch != null ? int.parse(priceMatch.group(0)!) : 0;
      final name = line.replaceAll(RegExp(r'\d+'), '').replaceAll('円', '').trim();
      if (name.isNotEmpty) {
        setState(() {
          _nameController.text = name;
          _priceController.text = price.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEdit = widget.initialData != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'サブスクを編集' : 'サブスクを追加')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isEdit) ...[
                const Text('人気サービスから選ぶ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                // ★ 横スクロールで選べるボタン
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: popularServices.length,
                    itemBuilder: (context, index) {
                      final service = popularServices[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ActionChip(
                          avatar: const Icon(Icons.star, size: 16, color: Colors.orange),
                          label: Text(service['name']),
                          onPressed: () => _setPopularService(service),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                
                TextField(
                  controller: _memoController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'メモを貼り付けて解析', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _parseMemo,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('メモから読み取る'),
                ),
                const Divider(height: 40),
              ],
              
              const Text('サービス名', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _nameController),
              const SizedBox(height: 20),

              const Text('ジャンル', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _genreController),
              Wrap(
                spacing: 8,
                children: genreSamples.map((g) => ActionChip(
                  label: Text(g),
                  onPressed: () => _genreController.text = g,
                )).toList(),
              ),
              const SizedBox(height: 20),

              const Text('毎月の支払日（1〜31日）', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: _dayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '例: 15'),
              ),
              const SizedBox(height: 20),

              const Text('月額（円）', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'name': _nameController.text,
                    'price': int.tryParse(_priceController.text) ?? 0,
                    'genre': _genreController.text.isEmpty ? 'その他' : _genreController.text,
                    'day': int.tryParse(_dayController.text) ?? 1,
                  });
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(isEdit ? '変更を保存する' : '新しく追加する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}