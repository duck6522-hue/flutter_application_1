import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = Colors.blue;

  void toggleDarkMode(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  void changeColor(Color color) {
    setState(() => _primaryColor = color);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'サブスク管理 Pro',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _primaryColor,
        brightness: Brightness.light,
        // ★フォント設定をモダンに変更
        fontFamily: 'sans-serif', 
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
          titleLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.5),
          bodyMedium: TextStyle(letterSpacing: 0.2),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _primaryColor,
        brightness: Brightness.dark,
        fontFamily: 'sans-serif',
      ),
      home: const HomeScreen(),
    );
  }
}