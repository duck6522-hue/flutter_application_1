import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
  static _MyAppState? of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = Colors.blue;

  void toggleDarkMode(bool isDark) => setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  void changeColor(Color color) => setState(() => _primaryColor = color);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'サブスク管理 Pro',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }

  // テーマ色はシード色としてだけ使い、文字色などはMaterialに自動で決めさせる(読みやすさ優先)
  ThemeData _buildTheme(Brightness brightness) {
    var cs = ColorScheme.fromSeed(seedColor: _primaryColor, brightness: brightness);
    final isDark = brightness == Brightness.dark;
    if (!isDark) {
      // ライトはテーマ色そのものの鮮やかさを使う(白文字が読める明るさまでに抑える)
      final hsl = HSLColor.fromColor(_primaryColor);
      final vivid = hsl.withLightness(hsl.lightness.clamp(0.28, 0.48)).withSaturation(hsl.saturation.clamp(0.45, 1.0)).toColor();
      cs = cs.copyWith(primary: vivid, onPrimary: Colors.white, surface: Colors.white, surfaceContainerLow: const Color(0xFFF4F5F9));
    }
    // ライトは色味のない明るいグレー背景＋白カードですっきり見せる
    final bg = isDark ? cs.surfaceContainerLow : const Color(0xFFF4F5F9);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: 'NotoSansJP',
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        dividerColor: cs.outlineVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: cs.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? cs.surfaceContainerHigh : Colors.white,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
    );
  }
}
