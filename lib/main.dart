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
      theme: ThemeData(
        useMaterial3: true,
        // ★ハッキリした色にするために primary を直接指定
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor, 
          primary: _primaryColor, 
          brightness: Brightness.light
        ),
        fontFamily: 'sans-serif',
        appBarTheme: AppBarTheme(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor, 
          primary: _primaryColor, 
          brightness: Brightness.dark
        ),
        fontFamily: 'sans-serif',
      ),
      home: const HomeScreen(),
    );
  }
}