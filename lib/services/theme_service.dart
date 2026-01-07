import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeService() {
    _loadThemeMode();
  }

  //  自分株式会社 Corporate Identity Colors
  static const Color _corpNavy =
      Color(0xFF0F172A); // Deep Strategy Navy (CEO/CSO)
  static const Color _corpGold =
      Color(0xFFD4AF37); // Prosperity Gold (Wealth/Reward)
  static const Color _corpBlueGrey = Color(0xFF334155); // Professional Grey
  static const Color _bgLight = Color(0xFFF8FAFC); // Clean Office White
  static const Color _bgDark = Color(0xFF020617); // Midnight Strategy Room

  // 役職別カラー（アクセントとして使用）
  static const Color roleCso = Color(0xFF475569); // BlueGrey
  static const Color roleCfo = Color(0xFF0D9488); // Teal
  static const Color roleCho = Color(0xFF166534); // Green
  static const Color roleCmo = Color(0xFF7E22CE); // Purple
  static const Color roleChro = Color(0xFFBE185D); // Pink
  static const Color roleCko = Color(0xFF4338CA); // Indigo

  ThemeMode getFlutterThemeMode() => _themeMode;

  // 追加: HomePageなどで参照されているゲッター
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _themeMode.toString());
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode');
    if (themeString != null) {
      if (themeString == 'ThemeMode.light') _themeMode = ThemeMode.light;
      if (themeString == 'ThemeMode.dark') _themeMode = ThemeMode.dark;
      notifyListeners();
    }
  }

  //  Light Theme (Daytime Office)
  ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _corpNavy,
        primary: _corpNavy,
        secondary: _corpGold,
        surface: Colors.white,
        background: _bgLight,
        error: Colors.red.shade700,
      ),
      scaffoldBackgroundColor: _bgLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: _corpNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: _corpNavy.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _corpNavy,
          foregroundColor: Colors.white,
          elevation: 3,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _corpNavy,
          side: const BorderSide(color: _corpNavy),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _corpGold,
        foregroundColor: _corpNavy,
        elevation: 4,
      ),
      dividerTheme: DividerThemeData(color: _corpBlueGrey.withOpacity(0.2)),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  //  Dark Theme (Night Strategy Room)
  ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _corpNavy,
        brightness: Brightness.dark,
        primary: Colors.white,
        secondary: _corpGold,
        surface: _corpBlueGrey.withOpacity(0.2),
        background: _bgDark,
        error: Colors.red.shade400,
      ),
      scaffoldBackgroundColor: _bgDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: _bgDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: _corpBlueGrey.withOpacity(0.3),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _bgDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _corpGold,
        foregroundColor: _bgDark,
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.1)),
    );
  }
}
