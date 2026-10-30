import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_pill.dart';
import 'presets.dart';

class AddScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;
  final List<String> genres; // ホームからカテゴリリストを受け取る
  final Map<String, Color> genreColors; // カテゴリごとの表示色
  const AddScreen({super.key, this.editData, required this.genres, this.genreColors = const {}});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _formatter = NumberFormat('#,###');
  int _selectedMonth = 1;
  int _selectedDay = 1;
  late String _selectedGenre;
  bool _isYearly = false;
  bool _includeInMonthly = true;
  bool _isReviewing = false;
  String? _usage; // 利用頻度(任意): often / sometimes / rarely
  bool _showInMonthly = false; // 年払いを月額表示にも含めるか(デフォルトは含めない)

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
      _usage = widget.editData!['usage'];
      _showInMonthly = widget.editData!['showInMonthly'] ?? false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // 候補を選ぶと、名前と(あれば)カテゴリを入れる。金額は変わりやすいので入れない
  void _applyPreset(ServicePreset p) {
    setState(() {
      _nameController.text = p.name;
      if (widget.genres.contains(p.genre)) _selectedGenre = p.genre;
    });
  }

  int? get _price => int.tryParse(_priceController.text.trim());

  void _save() {
    final name = _nameController.text.trim();
    final price = _price;
    if (name.isEmpty || price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(name.isEmpty ? 'サービス名を入力してください' : '金額を数字で入力してください'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    Navigator.pop(context, {
      'name': name, 'price': price,
      'month': _selectedMonth, 'day': _selectedDay, 'genre': _selectedGenre,
      'isYearly': _isYearly, 'includeInMonthly': _includeInMonthly, 'isReviewing': _isReviewing, 'showInMonthly': _showInMonthly,
      'usage': _usage,
    });
  }

  Widget _section(String title, Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
        ),
        child,
      ]),
    );
  }

  InputDecoration _fieldDecoration({String? hint, String? suffix, IconData? icon}) {
    return InputDecoration(
      hintText: hint, suffixText: suffix, prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );
  }

  // 月額・年額の換算プレビュー
  Widget _buildPreview() {
    final cs = Theme.of(context).colorScheme;
    final price = _price;
    if (price == null || price <= 0) return const SizedBox.shrink();
    final text = _isYearly
        ? '月あたり 約${_formatter.format((price / 12).round())}円'
        : '年間 ${_formatter.format(price * 12)}円';
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Row(children: [
        Icon(Icons.calculate_outlined, size: 16, color: cs.primary),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary)),
      ]),
    );
  }

  Widget _dropdown<T>({required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return DropdownButtonFormField<T>(
      value: value, items: items, onChanged: onChanged,
      decoration: _fieldDecoration(),
      borderRadius: BorderRadius.circular(14),
    );
  }

  Widget _buildSwitchCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(children: [
        SwitchListTile(
          title: const Text('合計に含める', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('オフにすると合計・グラフから除外'),
          value: _includeInMonthly, onChanged: (v) => setState(() => _includeInMonthly = v),
        ),
        if (_isYearly) ...[
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('月額表示にも含める', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('オフなら年額表示・年払いの集計だけに入ります'),
            value: _showInMonthly, onChanged: (v) => setState(() => _showInMonthly = v),
          ),
        ],
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('解約を検討中', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('節約できる額として集計されます'),
          activeColor: Colors.orange, value: _isReviewing, onChanged: (v) => setState(() => _isReviewing = v),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.editData == null ? 'サブスクを追加' : 'サブスクを編集', style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (widget.editData == null)
            _section('よく使うサービスから選ぶ（任意）', SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: servicePresets.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppPill(
                    label: p.name,
                    dotColor: widget.genreColors[p.genre],
                    selected: _nameController.text == p.name,
                    onTap: () => _applyPreset(p),
                  ),
                )).toList(),
              ),
            )),
          _section('サービス名', TextField(
            controller: _nameController, textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration(hint: '例: Netflix', icon: Icons.sell_outlined),
          )),
          _section(_isYearly ? '年額' : '月額', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _priceController, keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              decoration: _fieldDecoration(hint: '0', suffix: '円', icon: Icons.payments_outlined),
              onChanged: (_) => setState(() {}),
            ),
            _buildPreview(),
          ])),
          _section('支払いサイクル', SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('月払い'), icon: Icon(Icons.calendar_month)),
                ButtonSegment(value: true, label: Text('年払い'), icon: Icon(Icons.event_note)),
              ],
              selected: {_isYearly},
              onSelectionChanged: (s) => setState(() => _isYearly = s.first),
            ),
          )),
          _section(_isYearly ? '毎年の更新日' : '毎月の支払日', Row(children: [
            if (_isYearly) ...[
              Expanded(child: _dropdown<int>(
                value: _selectedMonth,
                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}月'))),
                onChanged: (v) => setState(() => _selectedMonth = v!),
              )),
              const SizedBox(width: 12),
            ],
            Expanded(child: _dropdown<int>(
              value: _selectedDay,
              items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}日'))),
              onChanged: (v) => setState(() => _selectedDay = v!),
            )),
          ])),
          _section('カテゴリ', Wrap(spacing: 8, runSpacing: 8, children: widget.genres.map((g) => AppPill(
            label: g, dotColor: widget.genreColors[g], selected: _selectedGenre == g,
            onTap: () => setState(() => _selectedGenre = g),
          )).toList())),
          _section('利用頻度（任意）', Row(children: [
            for (final u in const [('often', 'よく使う'), ('sometimes', 'たまに'), ('rarely', 'ほぼ使わない')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                // もう一度押すと未設定に戻る
                child: AppPill(label: u.$2, selected: _usage == u.$1, onTap: () => setState(() => _usage = _usage == u.$1 ? null : u.$1)),
              ),
          ])),
          _section('オプション', _buildSwitchCard()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('保存する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ),
      ),
    );
  }
}
