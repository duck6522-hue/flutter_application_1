import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'ai_prompt.dart';
import 'csv_io.dart';
import 'date_calc.dart';
import 'add_screen.dart';
import 'app_pill.dart';
import 'main.dart';

// 一覧・合計の表示モード
enum ViewMode { monthly, yearly, monthlyOnly, yearlyOnly }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  // --- 状態管理 ---
  List<Map<String, dynamic>> _subs = [];
  // ★デフォルトカテゴリに「クレカ」と「AI」を追加
  // デフォルトのカテゴリ順: 固定費 → エンタメ → ツール → 副業 → その他
  static const List<String> _defaultGenres = ['家賃', 'ローン', '保険', '携帯代', 'クレカ', '動画', '音楽', 'ゲーム', 'AI', '家計管理', '副業', 'その他'];
  List<String> _genres = List<String>.from(_defaultGenres);

  // 色を選んでいないデフォルトカテゴリには、並び順に沿って 青緑→空色→青→紫→ピンク のグラデーションを付ける。
  // 金額の大きい固定費(家賃・ローン・保険…)が同じ青に固まらないよう、前半は色相の間隔を広げてある。
  // 家賃は一番大きくなりやすいので、ミントではなく鮮やかなシアンから始める。
  static const List<double> _defaultHues = [190, 213, 234, 252, 267, 280, 291, 302, 313, 324, 335];
  static final Map<String, Color> _defaultGenreColors = () {
    final names = _defaultGenres.where((g) => g != 'その他').toList();
    return {
      for (var i = 0; i < names.length; i++) names[i]: _vividColor(_defaultHues[i]),
    };
  }();

  // 色相から、見た目の明るさがそろうように明るさを補正した鮮やかな色を作る(青は暗く見えるので明るめ、青緑は明るく見えるので控えめ)
  static Color _vividColor(double hue) {
    double bump(double center, double width) => math.exp(-math.pow((hue - center) / width, 2));
    final l = 0.5 + 0.07 * bump(240, 28) - 0.04 * bump(185, 20);
    return HSLColor.fromAHSL(1, hue, 0.95, l).toColor();
  }
  Map<String, int> _genreColors = {};
  String _searchQuery = '';
  String _sortBy = 'price'; // 金額が高い順がデフォルト
  String? _filterGenre; // nullなら全カテゴリ
  final GlobalKey _captureKey = GlobalKey(); // 画面保存用
  final GlobalKey _shotKey = GlobalKey(); // 全体撮影用(縦長)
  bool _capturing = false; // 撮影中だけ全件を裏で描画する
  int _touchedIndex = -1; // 分析グラフでタップ中のカテゴリ
  int? _takeHome; // 手取り月収(任意。AI診断のプロンプトにだけ使う)
  ViewMode _viewMode = ViewMode.monthly; // 一番よく見る月額表示がデフォルト
  bool get _isYearlyView => _viewMode == ViewMode.yearly || _viewMode == ViewMode.yearlyOnly;
  final _formatter = NumberFormat('#,###');

  // ★復活！こだわりの21色パレット
  final List<Color> themeColors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.pink, Colors.teal,
    const Color(0xFF90CAF9), const Color(0xFFA5D6A7), const Color(0xFFF48FB1), 
    const Color(0xFFCE93D8), const Color(0xFFFFCC80), const Color(0xFFFFF59D), const Color(0xFF80DEEA),
    const Color(0xFF000080), const Color(0xFF000000), const Color(0xFF1A237E),
    const Color(0xFF0D47A1), const Color(0xFF004D40), const Color(0xFF37474F), const Color(0xFF212121),
    // ビビッド系(紫〜ピンク)
    const Color(0xFF651FFF), const Color(0xFF7C4DFF), const Color(0xFF8E2DE2), const Color(0xFFAA00FF),
    const Color(0xFFD500F9), const Color(0xFFE040FB), const Color(0xFFFF2D95), const Color(0xFFFF4081),
    const Color(0xFFF50057), const Color(0xFFFF1744),
  ];

  // ヘッダーのグラデーションごと変わるビビッドなプリセット(開始色, 終了色)
  final List<(String, Color, Color)> gradientPresets = [
    ('紫→ピンク', const Color(0xFF8E2DE2), const Color(0xFFFF2D95)),
    ('マゼンタ→紫', const Color(0xFFD500F9), const Color(0xFF651FFF)),
    ('青→紫', const Color(0xFF2979FF), const Color(0xFFAA00FF)),
    ('ピンク→オレンジ', const Color(0xFFFF2D95), const Color(0xFFFF9100)),
    ('赤→マゼンタ', const Color(0xFFFF1744), const Color(0xFFD500F9)),
    ('シアン→青', const Color(0xFF00B8D4), const Color(0xFF2962FF)),
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- データ保存・読込 ---
  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _subs = List<Map<String, dynamic>>.from(json.decode(prefs.getString('subscription_list') ?? '[]'));
      // デフォルト値にも「クレカ」「AI」を反映
      _takeHome = prefs.getInt('take_home');
      _genres = List<String>.from(json.decode(prefs.getString('genre_list') ?? json.encode(_defaultGenres)));
      _genreColors = Map<String, int>.from(json.decode(prefs.getString('genre_colors') ?? '{}'));
      // 既存の保存データにも新しいデフォルトカテゴリを1度だけ追加する(後で削除しても復活しない)
      if (!(prefs.getBool('genre_added_v2') ?? false)) {
        for (final g in ['副業', 'ゲーム', '家計管理']) {
          if (!_genres.contains(g)) _genres.add(g);
        }
        prefs.setBool('genre_added_v2', true);
      }
      // 並び順の見直し(保険・ローンの追加)を1度だけ適用する。削除済みのデフォルトは復活させない
      if (!(prefs.getBool('genre_order_v3') ?? false)) {
        final present = _genres.toSet()..addAll(['保険', 'ローン']);
        final defaults = _defaultGenres.where((g) => g != 'その他' && present.contains(g));
        final custom = _genres.where((g) => !_defaultGenres.contains(g));
        final hasOther = _genres.contains('その他');
        _genres = [...defaults.where((g) => g != '副業'), ...custom, if (present.contains('副業')) '副業', if (hasOther) 'その他'];
        prefs.setBool('genre_order_v3', true);
      }
      _keepOtherLast();
      prefs.setString('genre_list', json.encode(_genres));
      _sortList();
    });
  }

  // 「その他」は常に一番後ろにする
  void _keepOtherLast() {
    if (_genres.remove('その他')) _genres.add('その他');
  }

  Future<void> _saveAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription_list', json.encode(_subs));
    await prefs.setString('genre_list', json.encode(_genres));
    await prefs.setString('genre_colors', json.encode(_genreColors));
  }

  // --- 便利計算 ---
  // どの背景でも見えるように、明るさを範囲内に収める(黒や薄い黄色対策)
  Color _getGenreColor(String genre) {
    final base = _genreColors.containsKey(genre) ? Color(_genreColors[genre]!) : (_defaultGenreColors[genre] ?? Colors.grey.shade500);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(base);
    final l = dark ? hsl.lightness.clamp(0.55, 0.85) : hsl.lightness.clamp(0.28, 0.60);
    return hsl.withLightness(l.toDouble()).toColor();
  }

  Color _onColor(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : Colors.black87;

  int _calculateDaysUntil(int? month, int day, bool isYearly) => daysUntilNext(DateTime.now(), month, day, isYearly);

  // 表示モードごとに、どのサブスクを対象にするか
  //  月額: 月払い + 「月額にも含める」をオンにした年払い / 年額: 全部
  //  月払いのみ: 月払いだけ / 年払いのみ: 年払いだけ
  bool _inView(Map<String, dynamic> item) {
    final yearly = item['isYearly'] ?? false;
    switch (_viewMode) {
      case ViewMode.monthly: return !yearly || (item['showInMonthly'] ?? false);
      case ViewMode.yearly: return true;
      case ViewMode.monthlyOnly: return !yearly;
      case ViewMode.yearlyOnly: return yearly;
    }
  }

  int get _totalPrice => _subs
      .where((i) => (i['includeInMonthly'] ?? true) && _inView(i))
      .fold(0, (sum, i) => sum + _displayPrice(i));

  int get _reviewPrice => _subs
      .where((i) => (i['isReviewing'] ?? false) && _inView(i))
      .fold(0, (sum, i) => sum + _displayPrice(i));

  void _sortList() {
    setState(() {
      if (_sortBy == 'date') {
        _subs.sort((a, b) => _calculateDaysUntil(a['month'], a['day'], a['isYearly'] ?? false)
            .compareTo(_calculateDaysUntil(b['month'], b['day'], b['isYearly'] ?? false)));
      } else {
        _subs.sort((a, b) => (b['price'] as int).compareTo(a['price'] as int));
      }
    });
  }

  // --- 画面を画像(PNG)で保存 ---
  // 撮影のときだけ、本物の画面の裏に全件を縦長で描画して丸ごと画像にする(スクロールで切れない)
  List<Map<String, dynamic>> get _filteredSubs => _subs.where((sub) =>
      _inView(sub) &&
      sub['name'].toLowerCase().contains(_searchQuery.toLowerCase()) &&
      (_filterGenre == null || sub['genre'] == _filterGenre)).toList();

  Widget _buildCaptureLayer() {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final stamp = DateFormat('yyyy/MM/dd').format(DateTime.now());
    final children = _tabController.index == 0
        ? [_buildSummaryHeader(), ..._listItems(_filteredSubs)]
        : _analysisChildren();
    // スクロール領域の中に置くと、画面より縦に長くても全体が描画される
    return Positioned.fill(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: RepaintBoundary(
          key: _shotKey,
          child: Material(
            color: bg,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              ...children,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Text('サブスク管理 Pro ・ $stamp', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _saveScreenshot() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _shotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('no boundary');
      // 縦に長いときは解像度を下げて、画像サイズの上限(約8000px)に収める
      final ratio = (8000 / boundary.size.height).clamp(1.0, 2.5).toDouble();
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('no data');
      final blob = html.Blob([data.buffer.asUint8List()], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final name = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      html.AnchorElement(href: url)..setAttribute('download', 'subsc_$name.png')..click();
      html.Url.revokeObjectUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('全体を縦長の画像で保存しました'), behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('画像の保存に失敗しました'), behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  // --- 手取り月収(任意) ---
  Future<void> _saveTakeHome(int? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove('take_home');
    } else {
      await prefs.setInt('take_home', value);
    }
    if (mounted) setState(() => _takeHome = value);
  }

  void _editTakeHome() {
    final controller = TextEditingController(text: _takeHome?.toString() ?? '');
    void submit(BuildContext dialogContext) {
      final v = int.tryParse(controller.text.replaceAll(',', '').trim());
      _saveTakeHome(v != null && v > 0 ? v : null);
      Navigator.pop(dialogContext);
    }
    showDialog(context: context, builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('手取り月収', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: controller, autofocus: true, keyboardType: TextInputType.number,
          onSubmitted: (_) => submit(dialogContext),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          decoration: InputDecoration(
            hintText: '例: 300000', suffixText: '円',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        Text('毎月の振込額（ボーナスを除く）が目安です。入力は任意で、AI診断のプロンプトにだけ使い、この端末の中にだけ保存します。', style: TextStyle(fontSize: 12, color: Theme.of(dialogContext).colorScheme.onSurfaceVariant)),
      ]),
      actions: [
        if (_takeHome != null) TextButton(onPressed: () { _saveTakeHome(null); Navigator.pop(dialogContext); }, child: const Text('クリア')),
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
        FilledButton(onPressed: () => submit(dialogContext), child: const Text('保存')),
      ],
    ));
  }

  // --- AI診断用プロンプト ---
  void _showDiagnosisPrompt() {
    if (_subs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('サブスクを登録してから使ってください'), behavior: SnackBarBehavior.floating));
      return;
    }
    final prompt = buildDiagnosisPrompt(subs: _subs, daysUntil: _calculateDaysUntil, takeHome: _takeHome);
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sheetHandle(),
            const Text('AIに診断してもらう', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('コピーして、ChatGPT・Claude・Gemini などに貼り付けてください。', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Flexible(child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cs.brightness == Brightness.dark ? cs.surfaceContainerHigh : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant)),
              child: SingleChildScrollView(child: SelectableText(prompt, style: const TextStyle(fontSize: 12, height: 1.6))),
            )),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text('サービス名と金額がAIに送られます。気になる名前は貼り付ける前に消してください。', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
            ]),
            const SizedBox(height: 12),
            SafeArea(top: false, child: FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: prompt));
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('コピーしました。AIに貼り付けてください'), behavior: SnackBarBehavior.floating));
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('プロンプトをコピー', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            )),
          ]),
        );
      },
    );
  }

  // --- CSV出力 ---
  void _exportToCSV() {
    final bytes = utf8.encode(buildCsv(_subs, _genreColors));
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    html.AnchorElement(href: url)..setAttribute("download", "subsc_data_$stamp.csv")..click();
    html.Url.revokeObjectUrl(url);
  }

  // --- CSVから読み込み(引き継ぎ) ---
  // ファイル選択はタップの操作の中で開く必要があるため、設定シートを閉じた直後に呼ぶ
  void _importCsv() {
    final input = html.FileUploadInputElement()..accept = '.csv,text/csv';
    input.onChange.listen((_) {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) return;
      _readCsvFile(file, 'utf-8', (text) {
        // Excelで保存したShift_JISのCSVは文字化けするので、その場合は読み直す
        if (text.contains('\uFFFD')) {
          _readCsvFile(file, 'shift_jis', _confirmImport);
        } else {
          _confirmImport(text);
        }
      });
    });
    input.click();
  }

  void _readCsvFile(html.File file, String encoding, void Function(String) onDone) {
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) => onDone(reader.result as String? ?? ''));
    reader.readAsText(file, encoding);
  }

  String _dupKey(Map<String, dynamic> i) => '${i['name']}|${i['price']}|${i['isYearly'] ?? false}|${i['day']}|${i['genre']}';

  void _confirmImport(String text) {
    if (!mounted) return;
    final result = parseCsv(text);
    if (result.items.isEmpty) {
      showDialog(context: context, builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('読み込めませんでした', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: Text(result.errors.take(4).join('\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('閉じる'))],
      ));
      return;
    }
    final existing = _subs.map(_dupKey).toSet();
    final newItems = result.items.where((i) => !existing.contains(_dupKey(i))).toList();
    showDialog(context: context, builder: (c) {
      final cs = Theme.of(c).colorScheme;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('CSVを読み込む', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${result.items.length}件を読み込めます${result.errors.isEmpty ? '' : '（${result.errors.length}件は読み込めません）'}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('・追加: 今のデータに足します（同じ内容は${result.items.length - newItems.length}件スキップ）\n・置き換え: 今の${_subs.length}件を消して、CSVの内容にします', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.6)),
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(result.errors.take(3).join('\n') + (result.errors.length > 3 ? '\n…ほか${result.errors.length - 3}件' : ''), style: TextStyle(fontSize: 12, color: cs.error)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('キャンセル')),
          TextButton(onPressed: () { Navigator.pop(c); _applyImport(result, replace: false); }, child: const Text('追加')),
          FilledButton(onPressed: () { Navigator.pop(c); _applyImport(result, replace: true); }, child: const Text('置き換え')),
        ],
      );
    });
  }

  void _applyImport(CsvImport result, {required bool replace}) {
    setState(() {
      final existing = replace ? <String>{} : _subs.map(_dupKey).toSet();
      if (replace) _subs = [];
      for (final item in result.items) {
        if (existing.add(_dupKey(item))) _subs.add(item);
      }
      // CSVにあって、まだ無いジャンルは足す(「その他」は最後のまま)。色も引き継ぐ
      for (final item in result.items) {
        final g = item['genre'] as String;
        if (!_genres.contains(g)) _genres.add(g);
      }
      result.genreColors.forEach((g, c) => _genreColors.putIfAbsent(g, () => c));
      _keepOtherLast();
      _sortList();
    });
    _saveAllData();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(replace ? 'CSVの内容に置き換えました（${_subs.length}件）' : 'CSVから追加しました（合計${_subs.length}件）'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // --- UI構成 ---
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredSubs = _subs.where((sub) =>
        _inView(sub) &&
        sub['name'].toLowerCase().contains(_searchQuery.toLowerCase()) &&
        (_filterGenre == null || sub['genre'] == _filterGenre)).toList();

    return Scaffold(
        appBar: AppBar(
          title: const Text('サブスク管理 Pro', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1)),
          actions: [
            // ★カテゴリ管理ボタンを分かりやすくラベル付きに（または目立つアイコンに）
            TextButton.icon(
              onPressed: _showGenreManagement,
              icon: const Icon(Icons.category_rounded),
              label: const Text('カテゴリ設定', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            IconButton(tooltip: '画面を画像で保存', icon: const Icon(Icons.photo_camera_outlined), onPressed: _saveScreenshot),
            IconButton(icon: const Icon(Icons.tune_rounded), onPressed: () => _showSettings(isDark)),
          ],
          bottom: TabBar(controller: _tabController, tabs: const [Tab(text: '一覧'), Tab(text: '分析レポート')]),
        ),
        body: Stack(children: [
          if (_capturing) _buildCaptureLayer(), // 撮影中だけ、本物の画面の裏に全件を描画
          Positioned.fill(child: RepaintBoundary(
            key: _captureKey,
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBarView(
                controller: _tabController,
                children: [
                  Column(children: [
                    Expanded(child: _buildListView(filteredSubs)),
                  ]),
                  _buildAnalysisTab(),
                ],
              ),
            ),
          )),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddScreen(),
          label: const Text('サブスクを追加', style: TextStyle(fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.add),
        ),
    );
  }

  Color _headerEnd(ColorScheme cs) {
    final preset = MyApp.of(context)?.headerEnd;
    if (preset != null) {
      final p = HSLColor.fromColor(preset);
      if (cs.brightness == Brightness.dark) {
        // ダークは主色の明るさに合わせて色相だけ使う
        final base = HSLColor.fromColor(cs.primary);
        return base.withHue(p.hue).toColor();
      }
      return p.withLightness(p.lightness.clamp(0.3, 0.55)).toColor();
    }
    if (cs.brightness == Brightness.dark) return Color.lerp(cs.primary, cs.tertiary, 0.55)!;
    final hsl = HSLColor.fromColor(cs.primary);
    return hsl.withHue((hsl.hue + 35) % 360).withSaturation((hsl.saturation + 0.1).clamp(0.0, 1.0)).toColor();
  }

  String get _modeTitle {
    switch (_viewMode) {
      case ViewMode.monthly: return '月間合計';
      case ViewMode.yearly: return '年間合計';
      case ViewMode.monthlyOnly: return '月払いの合計';
      case ViewMode.yearlyOnly: return '年払いの合計';
    }
  }

  Widget _headerTile({required String label, required int value, required String unit, required IconData icon, required Color on, String? sub}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: on.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: on.withOpacity(0.85)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on.withOpacity(0.85))),
        ]),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text.rich(TextSpan(children: [
          TextSpan(text: _formatter.format(value), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: on)),
          TextSpan(text: ' 円/$unit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: on.withOpacity(0.85))),
        ]))),
        if (sub != null) Text(sub, style: TextStyle(fontSize: 11, color: on.withOpacity(0.8))),
      ]),
    );
  }

  Widget _buildSummaryHeader() {
    final cs = Theme.of(context).colorScheme;
    final on = cs.onPrimary;
    final int displayPrice = _totalPrice;
    final int displayReviewPrice = _reviewPrice;
    final int excludedYearly = _viewMode != ViewMode.monthly ? 0 : _subs.where((i) => (i['isYearly'] ?? false) && (i['includeInMonthly'] ?? true) && !_inView(i)).length;
    final counted = _subs.where((i) => i['includeInMonthly'] ?? true);
    final int monthlyBilled = counted.where((i) => !(i['isYearly'] ?? false)).fold(0, (sum, i) => sum + (i['price'] as int));
    final int yearlyBilled = counted.where((i) => i['isYearly'] ?? false).fold(0, (sum, i) => sum + (i['price'] as int));
    return Container(
      padding: const EdgeInsets.all(22), margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [cs.primary, _headerEnd(cs)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_modeTitle, style: TextStyle(color: on.withOpacity(0.8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text('${_formatter.format(displayPrice)} 円', style: TextStyle(fontSize: 38, color: on, fontWeight: FontWeight.w900, letterSpacing: -1))),
            if (excludedYearly > 0) Text('年払い$excludedYearly件は含まず', style: TextStyle(fontSize: 12, color: on.withOpacity(0.8))),
            if (_viewMode == ViewMode.yearlyOnly && displayPrice > 0) Text('月あたり 約${_formatter.format((displayPrice / 12).round())}円', style: TextStyle(fontSize: 12, color: on.withOpacity(0.8))),
            if (_viewMode == ViewMode.monthlyOnly && displayPrice > 0) Text('年間 ${_formatter.format(displayPrice * 12)}円', style: TextStyle(fontSize: 12, color: on.withOpacity(0.8))),
          ])),
          Icon(Icons.auto_graph_rounded, color: on.withOpacity(0.35), size: 48),
        ]),
        if (_viewMode == ViewMode.monthly || _viewMode == ViewMode.yearly) ...[
        const SizedBox(height: 14),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _headerTile(label: '月払い', value: monthlyBilled * (_isYearlyView ? 12 : 1), unit: _isYearlyView ? '年' : '月', icon: Icons.calendar_month_rounded, on: on)),
          const SizedBox(width: 10),
          Expanded(child: _headerTile(label: '年払い', value: yearlyBilled, unit: '年', icon: Icons.event_note_rounded, on: on, sub: _isYearlyView || yearlyBilled == 0 ? null : '月あたり ${_formatter.format((yearlyBilled / 12).round())}円')),
        ])),
        ],
        if (displayReviewPrice > 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: on.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Icons.savings_rounded, size: 18, color: on),
              const SizedBox(width: 8),
              Expanded(child: Text('解約すると節約できる額', style: TextStyle(color: on, fontSize: 13, fontWeight: FontWeight.bold))),
              Text('- ${_formatter.format(displayReviewPrice)} 円', style: TextStyle(color: on, fontSize: 16, fontWeight: FontWeight.w900)),
            ]),
          ),
        ]
      ]),
    );
  }

  Widget _buildToggleSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ViewMode>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
          ),
          segments: const [
            ButtonSegment(value: ViewMode.monthly, label: Text('月額', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
            ButtonSegment(value: ViewMode.yearly, label: Text('年額', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
            ButtonSegment(value: ViewMode.monthlyOnly, label: Text('月払いのみ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
            ButtonSegment(value: ViewMode.yearlyOnly, label: Text('年払いのみ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
          ],
          selected: <ViewMode>{_viewMode},
          onSelectionChanged: (set) => setState(() => _viewMode = set.first),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'サービス名で検索...', prefixIcon: const Icon(Icons.search),
          filled: true, isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  // カテゴリ絞り込み + 並び替え
  Widget _buildFilterBar() {
    return Column(children: [
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppPill(label: 'すべて', selected: _filterGenre == null, onTap: () => setState(() => _filterGenre = null)),
            ),
            ..._genres.map((g) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppPill(
                label: g, dotColor: _getGenreColor(g), selected: _filterGenre == g,
                onTap: () => setState(() => _filterGenre = _filterGenre == g ? null : g),
              ),
            )),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text('${_subs.length}件', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.sort, size: 18, color: Colors.grey),
          const SizedBox(width: 4),
          DropdownButton<String>(
            value: _sortBy, underline: const SizedBox.shrink(), isDense: true,
            items: const [
              DropdownMenuItem(value: 'date', child: Text('支払日が近い順')),
              DropdownMenuItem(value: 'price', child: Text('金額が高い順')),
            ],
            onChanged: (v) { if (v != null) { _sortBy = v; _sortList(); } },
          ),
        ]),
      ),
    ]);
  }

  // 支払日までの日数に応じたバッジ
  Widget _buildDaysBadge(int diff) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color c = diff <= 3
        ? (dark ? Colors.red.shade300 : Colors.red.shade700)
        : (diff <= 7 ? (dark ? Colors.orange.shade300 : Colors.deepOrange.shade700) : Theme.of(context).colorScheme.onSurfaceVariant);
    final String label = diff == 0 ? '今日' : 'あと$diff日';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildTag(String text, Color c, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.22), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 3)],
        Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  int _displayPrice(Map<String, dynamic> item) {
    final yearly = item['isYearly'] ?? false;
    return _isYearlyView ? (yearly ? item['price'] : item['price'] * 12) : (yearly ? (item['price'] / 12).round() : item['price']);
  }

  // 月払い/年払いの区切り見出し(件数と小計つき)
  Widget _buildSectionHeader(bool yearly, List<Map<String, dynamic>> items) {
    final cs = Theme.of(context).colorScheme;
    final counted = items.where((i) => i['includeInMonthly'] ?? true);
    // 小計は表示中の単位(月/年)で出す
    final subtotal = counted.fold<int>(0, (sum, i) => sum + _displayPrice(i));
    final unit = _isYearlyView ? '年' : '月';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: cs.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(yearly ? Icons.event_note_rounded : Icons.calendar_month_rounded, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Text(yearly ? '年払い' : '月払い', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Text('${items.length}件', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
        const Spacer(),
        Text('小計 ${_formatter.format(subtotal)}円/$unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  // 月払い → 年払いの順に、見出しを挟んで並べたウィジェット列(一覧本体)
  List<Widget> _listItems(List<Map<String, dynamic>> list) {
    final monthly = list.where((i) => !(i['isYearly'] ?? false)).toList();
    final yearlyItems = list.where((i) => i['isYearly'] ?? false).toList();
    return [
      if (monthly.isNotEmpty) ...[_buildSectionHeader(false, monthly), ...monthly.map(_buildSubCard)],
      if (yearlyItems.isNotEmpty) ...[_buildSectionHeader(true, yearlyItems), ...yearlyItems.map(_buildSubCard)],
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.all(48),
          child: Column(children: [
            const Icon(Icons.inbox_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 8),
            Text(_viewMode == ViewMode.yearlyOnly ? '年払いのサブスクがありません' : (_viewMode == ViewMode.monthlyOnly ? '月払いのサブスクがありません' : '該当するサブスクがありません'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ]),
        ),
    ];
  }

  Widget _buildListView(List<Map<String, dynamic>> list) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 96), // FABと重ならない余白
      children: [
        _buildSummaryHeader(),
        _buildToggleSwitch(),
        _buildSearchField(),
        _buildFilterBar(),
        ..._listItems(list),
      ],
    );
  }

  Widget _buildSubCard(Map<String, dynamic> item) {
        final bool include = item['includeInMonthly'] ?? true;
        final bool reviewing = item['isReviewing'] ?? false;
        final bool yearly = item['isYearly'] ?? false;
        final int diff = _calculateDaysUntil(item['month'], item['day'], yearly);
        final int itemPrice = _displayPrice(item);
        final Color gc = _getGenreColor(item['genre']);
        final String dateText = yearly ? '毎年${item['month']}月${item['day']}日' : '毎月${item['day']}日';
        final String unit = _isYearlyView ? '/年' : '/月';

        return Card(
          elevation: 0, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          clipBehavior: Clip.antiAlias,
          color: reviewing ? Colors.orange.withOpacity(0.12) : (include ? null : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: reviewing ? Colors.orange : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5))),
          child: InkWell(
            onTap: () => _openAddScreen(index: _subs.indexOf(item)),
            onLongPress: () => _deleteSub(_subs.indexOf(item)),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 6, color: gc), // カテゴリ色のライン
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, decoration: include ? null : TextDecoration.lineThrough, color: include ? null : Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        _buildDaysBadge(diff),
                        Text(dateText, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        _buildTag(item['genre'], gc),
                        if (yearly && (item['showInMonthly'] ?? false)) _buildTag('月額にも含む', Colors.indigo),
                        if (item['usage'] == 'often') _buildTag('よく使う', Colors.green),
                        if (item['usage'] == 'sometimes') _buildTag('たまに', Colors.blueGrey),
                        if (item['usage'] == 'rarely') _buildTag('ほぼ使わない', Colors.deepOrange),
                        if (reviewing) _buildTag('検討中', Colors.orange, icon: Icons.warning_amber_rounded),
                        if (!include) _buildTag('合計外', Colors.grey),
                      ]),
                    ])),
                    const SizedBox(width: 8),
                    Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      // 年払いは実際の請求額を主表示にし、月換算は補足にする
                      Text('${_formatter.format(yearly ? item['price'] : itemPrice)}円', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      Text(
                        yearly ? (_isYearlyView ? '/年' : '/年・月あたり${_formatter.format(itemPrice)}円') : unit,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ]),
                  ]),
                )),
              ]),
            ),
          ),
        );
  }

  // 色相を少しずらした明るめの色(グラデーションの終点用)
  Color _shiftColor(Color c, {double hue = 28, double light = 0.07}) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withHue((hsl.hue + hue) % 360).withLightness((hsl.lightness + light).clamp(0.0, 0.8)).toColor();
  }

  LinearGradient _colorGradient(Color c) => LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [c, _shiftColor(c)]);

  Widget _analysisCard({required String title, required Widget child, IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primary, _headerEnd(cs)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon ?? Icons.insights_rounded, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      ),
    );
  }

  // 横棒1本分: 色マーク(または順位バッジ) + 名前 + グラデーションの棒 + 金額/割合
  Widget _barRow({required String label, required Color color, required double ratio, required String amount, String? sub, bool active = true, int? rank}) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: active ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (rank != null)
              Container(
                width: 24, height: 24, alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, _shiftColor(color)])),
                child: Text('$rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _onColor(color))),
              )
            else
              Container(width: 12, height: 12, decoration: BoxDecoration(gradient: _colorGradient(color), shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(amount, style: const TextStyle(fontWeight: FontWeight.w900)),
            if (sub != null) SizedBox(width: 52, child: Text(sub, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 8),
          Container(
            height: 12,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0.02, 1.0),
              child: Container(decoration: BoxDecoration(gradient: _colorGradient(color), borderRadius: BorderRadius.circular(8))),
            ),
          ),
        ]),
      ),
    );
  }

  // 分析タブの先頭: ヘッダーと同じグラデーションの合計カード + カテゴリ構成の積み上げバー
  Widget _buildAnalysisHero(List<MapEntry<String, int>> entries, int total) {
    final cs = Theme.of(context).colorScheme;
    final on = cs.onPrimary;
    final top = entries.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primary, _headerEnd(cs)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_modeTitle, style: TextStyle(color: on.withOpacity(0.85), fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text('${_formatter.format(total)} 円', style: TextStyle(fontSize: 34, color: on, fontWeight: FontWeight.w900, letterSpacing: -1))),
          ])),
          Icon(Icons.donut_large_rounded, color: on.withOpacity(0.35), size: 44),
        ]),
        const SizedBox(height: 4),
        Text('最大は「${top.key}」 ${(top.value / total * 100).toStringAsFixed(0)}%・${entries.length}カテゴリ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on.withOpacity(0.85))),
        const SizedBox(height: 14),
        // カテゴリ構成の積み上げバー(色の間に2pxの隙間)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: (entries[i].value * 1000 ~/ total).clamp(1, 1000),
                  child: Container(decoration: BoxDecoration(gradient: _colorGradient(_getGenreColor(entries[i].key)))),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildAnalysisTab() => ListView(
    padding: const EdgeInsets.only(top: 10, bottom: 96),
    children: [..._analysisChildren(), _buildDiagnosisCard()],
  );

  // 分析タブの一番下: AI診断プロンプトへの入口(画像保存には含めない)
  Widget _buildDiagnosisCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _showDiagnosisPrompt,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: cs.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.auto_awesome_rounded, color: cs.primary),
            ),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AIに診断してもらう', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              SizedBox(height: 2),
              Text('現状をまとめたプロンプトをコピー', style: TextStyle(fontSize: 12)),
            ])),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }

  List<Widget> _analysisChildren() {
    final cs = Theme.of(context).colorScheme;
    final counted = _subs.where((i) => (i['includeInMonthly'] ?? true) && _inView(i)).toList();
    final Map<String, int> totals = {};
    for (var item in counted) {
      totals[item['genre']] = (totals[item['genre']] ?? 0) + _displayPrice(item);
    }
    if (totals.isEmpty) {
      return [Padding(
        padding: const EdgeInsets.only(top: 80, bottom: 80),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.donut_large_rounded, size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text('分析データがありません', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
        ])),
      )];
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    final top = counted.toList()..sort((a, b) => _displayPrice(b).compareTo(_displayPrice(a)));
    final topItems = top.take(5).toList();
    final touched = (_touchedIndex >= 0 && _touchedIndex < entries.length) ? entries[_touchedIndex] : null;
    final unitLabel = _modeTitle;

    return [
        _buildAnalysisHero(entries, total),
        _analysisCard(
          icon: Icons.donut_large_rounded,
          title: 'カテゴリ別の割合',
          child: Column(children: [
            SizedBox(
              height: 240,
              child: Stack(alignment: Alignment.center, children: [
                PieChart(PieChartData(
                  startDegreeOffset: 270, sectionsSpace: 3, centerSpaceRadius: 74,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(touchCallback: (event, resp) {
                    final i = resp?.touchedSection?.touchedSectionIndex ?? -1;
                    if (!event.isInterestedForInteractions || i < 0) {
                      if (_touchedIndex != -1) setState(() => _touchedIndex = -1);
                    } else if (i != _touchedIndex) {
                      setState(() => _touchedIndex = i);
                    }
                  }),
                  sections: List.generate(entries.length, (i) {
                    final c = _getGenreColor(entries[i].key);
                    return PieChartSectionData(
                      color: c,
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c, _shiftColor(c)]),
                      value: entries[i].value.toDouble(),
                      radius: _touchedIndex == i ? 44 : 36,
                      showTitle: false,
                    );
                  }),
                )),
                // 中心: 合計 or タップ中カテゴリの詳細
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(touched?.key ?? unitLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text('${_formatter.format(touched?.value ?? total)}円', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  if (touched != null)
                    Text('${(touched.value / total * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _getGenreColor(touched.key))),
                ]),
              ]),
            ),
            Text('リングをタップすると詳細が見られます', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
        ),
        _analysisCard(
          icon: Icons.leaderboard_rounded,
          title: 'カテゴリ別ランキング',
          child: Column(children: List.generate(entries.length, (i) {
            final e = entries[i];
            return GestureDetector(
              onTap: () => setState(() => _touchedIndex = _touchedIndex == i ? -1 : i),
              behavior: HitTestBehavior.opaque,
              child: _barRow(
                label: e.key, color: _getGenreColor(e.key), ratio: e.value / entries.first.value,
                amount: '${_formatter.format(e.value)}円', sub: '${(e.value / total * 100).toStringAsFixed(0)}%',
                active: _touchedIndex == -1 || _touchedIndex == i,
              ),
            );
          })),
        ),
        _analysisCard(
          icon: Icons.local_fire_department_rounded,
          title: '高いサブスク TOP${topItems.length}',
          child: Column(children: [
            for (var r = 0; r < topItems.length; r++)
              _barRow(
                rank: r + 1,
                label: topItems[r]['name'], color: _getGenreColor(topItems[r]['genre']),
                ratio: _displayPrice(topItems[r]) / _displayPrice(topItems.first),
                amount: '${_formatter.format(_displayPrice(topItems[r]))}円',
                sub: '${(_displayPrice(topItems[r]) / total * 100).toStringAsFixed(0)}%',
              ),
          ]),
        ),
    ];
  }

  // --- カテゴリ管理・色選択 ---
  Widget _sheetHandle() => Center(
    child: Container(
      width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
    ),
  );

  void _showGenreManagement() {
    final addController = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => StatefulBuilder(builder: (context, setModalState) {
        final cs = Theme.of(context).colorScheme;
        void addGenre() {
          final name = addController.text.trim();
          if (name.isEmpty) return;
          if (_genres.contains(name)) {
            ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('同じ名前のカテゴリがあります'), behavior: SnackBarBehavior.floating));
            return;
          }
          setState(() { setModalState(() { _genres.add(name); _keepOtherLast(); }); _saveAllData(); });
          addController.clear();
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(),
            const Text('カテゴリ設定', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('左の色の丸をタップすると色を変えられます', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 16),
            Flexible(child: ListView.separated(
              shrinkWrap: true,
              itemCount: _genres.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final g = _genres[i];
                final used = _subs.where((e) => e['genre'] == g).length;
                final c = _getGenreColor(g);
                return Material(
                  color: cs.brightness == Brightness.dark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: GestureDetector(
                      onTap: () => _pickGenreColor(g, setModalState),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        child: Icon(Icons.palette_outlined, size: 18, color: _onColor(c)),
                      ),
                    ),
                    title: Text(g, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(used == 0 ? '未使用' : '$used件で使用中', style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: used == 0 ? cs.error : cs.outline),
                      onPressed: () {
                        if (used > 0) {
                          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('「$g」は$used件のサブスクで使用中のため削除できません'), behavior: SnackBarBehavior.floating));
                          return;
                        }
                        setState(() { setModalState(() => _genres.removeAt(i)); _saveAllData(); });
                      },
                    ),
                  ),
                );
              },
            )),
            const SizedBox(height: 16),
            TextField(
              controller: addController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: '新しいカテゴリ名',
                prefixIcon: const Icon(Icons.add_rounded),
                suffixIcon: IconButton(icon: const Icon(Icons.check_circle_rounded), color: cs.primary, onPressed: addGenre),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => addGenre(),
            ),
          ]),
        );
      }),
    );
  }

  void _pickGenreColor(String genre, StateSetter setModalState) {
    final current = _genreColors[genre];
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('「$genre」の色', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      content: SizedBox(
        width: 320,
        child: Wrap(spacing: 12, runSpacing: 12, children: themeColors.map((c) {
          final selected = current == c.value;
          return GestureDetector(
            onTap: () { setState(() { setModalState(() => _genreColors[genre] = c.value); _saveAllData(); }); Navigator.pop(context); },
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: c, shape: BoxShape.circle,
                border: Border.all(color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.outlineVariant, width: selected ? 3 : 1),
              ),
              child: selected ? Icon(Icons.check_rounded, color: _onColor(c)) : null,
            ),
          );
        }).toList()),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる'))],
    ));
  }

  void _showSettings(bool isDark) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(child: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sheetHandle(),
            const Text('設定', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('ダークモード', style: TextStyle(fontWeight: FontWeight.w700)), secondary: const Icon(Icons.dark_mode_outlined), value: isDark, onChanged: (v) { MyApp.of(context)?.toggleDarkMode(v); Navigator.pop(context); }),
            ListTile(
              contentPadding: EdgeInsets.zero, leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('手取り月収（任意）', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_takeHome == null ? '未設定・AI診断で収入に対する割合を見たいときに' : '${_formatter.format(_takeHome)}円'),
              onTap: () { Navigator.pop(context); _editTakeHome(); },
            ),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.auto_awesome_rounded), title: const Text('AIに診断してもらう（プロンプトをコピー）', style: TextStyle(fontWeight: FontWeight.w700)), onTap: () { Navigator.pop(context); _showDiagnosisPrompt(); }),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.download_rounded), title: const Text('CSVで書き出す（引き継ぎ用）', style: TextStyle(fontWeight: FontWeight.w700)), onTap: () { _exportToCSV(); Navigator.pop(context); }),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.upload_rounded), title: const Text('CSVから読み込む（引き継ぎ）', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('書き出したCSVでデータを戻せます'), onTap: () { Navigator.pop(context); _importCsv(); }),
            const Divider(),
            const SizedBox(height: 8),
            Text('ビビッドグラデーション', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(spacing: 14, runSpacing: 12, children: gradientPresets.map((g) {
              final app = MyApp.of(context);
              final selected = app?.primaryColor.value == g.$2.value && app?.headerEnd?.value == g.$3.value;
              return GestureDetector(
                onTap: () { MyApp.of(context)?.changeColor(g.$2, end: g.$3); Navigator.pop(context); },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [g.$2, g.$3]),
                      border: Border.all(color: selected ? cs.onSurface : Colors.transparent, width: 3),
                    ),
                    child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                  ),
                  const SizedBox(height: 4),
                  Text(g.$1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
              );
            }).toList()),
            const SizedBox(height: 18),
            Text('テーマカラー', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: themeColors.map((c) {
              final app = MyApp.of(context);
              final selected = app?.primaryColor.value == c.value && app?.headerEnd == null;
              return GestureDetector(
                onTap: () { MyApp.of(context)?.changeColor(c); Navigator.pop(context); },
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: selected ? cs.onSurface : cs.outlineVariant, width: selected ? 3 : 1)),
                  child: selected ? Icon(Icons.check_rounded, size: 18, color: _onColor(c)) : null,
                ),
              );
            }).toList()),
          ]),
        )));
      },
    );
  }

  void _deleteSub(int i) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('削除確認'), content: const Text('このサブスクを削除しますか？'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
      TextButton(onPressed: () async { setState(() => _subs.removeAt(i)); await _saveAllData(); Navigator.pop(context); }, child: const Text('削除', style: TextStyle(color: Colors.red)))],
    ));
  }

  Future<void> _openAddScreen({int? index}) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddScreen(editData: index != null ? _subs[index] : null, genres: _genres, genreColors: {for (final g in _genres) g: _getGenreColor(g)})));
    if (result != null) { setState(() { if (index != null) _subs[index] = result; else _subs.add(result); _sortList(); }); _saveAllData(); }
  }
}