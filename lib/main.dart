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
    final cs = ColorScheme.fromSeed(seedColor: _primaryColor, brightness: brightness);
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: 'sans-serif',
      scaffoldBackgroundColor: cs.surfaceContainerLow,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surfaceContainerLow,
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
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: cs.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
    );
  }
}
