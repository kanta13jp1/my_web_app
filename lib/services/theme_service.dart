import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = const Color(0xFF0F172A); // Default Navy

  ThemeService() {
    _loadThemeMode();
  }

  // Getters
  ThemeMode getFlutterThemeMode() => _themeMode;
  ThemeMode get themeMode => _themeMode; // SettingsPage用
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Color get primaryColor => _primaryColor;

  // Colors
  static const Color roleCso = Color(0xFF475569);
  static const Color roleCfo = Color(0xFF0D9488);
  static const Color roleCho = Color(0xFF166534);
  static const Color roleCmo = Color(0xFF7E22CE);
  static const Color roleChro = Color(0xFFBE185D);
  static const Color roleCko = Color(0xFF4338CA);

  // Methods
  void toggleTheme() async {
    setThemeMode(
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString());
  }

  void setPrimaryColor(Color color) {
    _primaryColor = color;
    notifyListeners();
    // 保存処理は必要に応じて実装
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode');
    if (themeString != null) {
      if (themeString == 'ThemeMode.light') _themeMode = ThemeMode.light;
      if (themeString == 'ThemeMode.dark') _themeMode = ThemeMode.dark;
      if (themeString == 'ThemeMode.system') _themeMode = ThemeMode.system;
      notifyListeners();
    }
  }

  ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF020617), // Very Dark Navy
        foregroundColor: Colors.white,
      ),
    );
  }
}
