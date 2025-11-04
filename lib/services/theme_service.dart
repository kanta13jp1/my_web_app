import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart'; // ← 追加

enum AppThemeMode {
  light,
  dark,
  system,
}

class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _primaryColorKey = 'primary_color';

  AppThemeMode _themeMode = AppThemeMode.system;
  Color _primaryColor = Colors.blue;

  AppThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;

  ThemeService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // テーマモードを読み込み
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? 2; // デフォルト: system
    _themeMode = AppThemeMode.values[themeModeIndex];

    // プライマリカラーを読み込み
    final colorValue = prefs.getInt(_primaryColorKey);
    if (colorValue != null) {
      _primaryColor = Color(colorValue);
    }

    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();

    // 色のコンポーネントから32ビット整数値を構築
    final colorValue = ((color.a * 255).toInt() << 24) |
        ((color.r * 255).toInt() << 16) |
        ((color.g * 255).toInt() << 8) |
        ((color.b * 255).toInt() << 0);

    await prefs.setInt(_primaryColorKey, colorValue);
    notifyListeners();
  }

  // ライトテーマを取得
  ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.notoSansJpTextTheme(), // ← 追加
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
    );
  }

  // ダークテーマを取得
  ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.notoSansJpTextTheme(
        // ← 追加
        ThemeData.dark().textTheme,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.grey[900],
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.grey[850],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
    );
  }

  // FlutterのThemeModeに変換
  ThemeMode getFlutterThemeMode() {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  // 現在のブライトネスを取得
  Brightness getCurrentBrightness(BuildContext context) {
    if (_themeMode == AppThemeMode.system) {
      return MediaQuery.of(context).platformBrightness;
    }
    return _themeMode == AppThemeMode.dark ? Brightness.dark : Brightness.light;
  }
}
