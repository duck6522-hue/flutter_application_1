import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();

  static MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>();
}

class MyAppState extends State<MyApp> {
  Color _themeColor = Colors.blue;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeColor = Color(prefs.getInt('theme_color') ?? Colors.blue.toARGB32());
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    });
  }

  void changeColor(Color color) async {
    setState(() => _themeColor = color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.toARGB32());
  }

  void toggleDarkMode(bool value) async {
    setState(() => _isDarkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'サブスク管理',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _themeColor, brightness: Brightness.light),
        useMaterial3: true,
        appBarTheme: AppBarTheme(backgroundColor: _themeColor, foregroundColor: Colors.white),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _themeColor, brightness: Brightness.dark),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}