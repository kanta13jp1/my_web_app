import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _appFontFamily = 'NotoSansJP';
  static const List<String> _appFontFallback = <String>[
    'NotoSansJP',
    'NotoSans',
    'NotoColorEmoji',
  ];

  // 日本語タイポグラフィ最適化 (awesome-design-md-jp 準拠)
  // 本文: height 1.7 (line-height ≥ 1.5 は日本語テキストの必須要件)
  // 見出し: height 1.4 (日本語見出しは欧文より少し大きめ)
  // letterSpacing: 本文 null (normalのまま)、見出しのみ 0.04em 相当
  static TextTheme _buildJaTextTheme(TextTheme base) {
    return base.copyWith(
      // Display / Headline (ページ大タイトル相当)
      displayLarge: base.displayLarge?.copyWith(height: 1.3),
      displayMedium: base.displayMedium?.copyWith(height: 1.3),
      displaySmall: base.displaySmall?.copyWith(height: 1.35),
      headlineLarge: base.headlineLarge?.copyWith(
        height: 1.4,
        letterSpacing: 0.96, // 0.04em × 24px (H1相当)
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        height: 1.4,
        letterSpacing: 0.72, // 0.04em × 18px (H2相当)
      ),
      headlineSmall: base.headlineSmall?.copyWith(height: 1.4),
      titleLarge: base.titleLarge?.copyWith(height: 1.4),
      titleMedium: base.titleMedium?.copyWith(height: 1.4),
      titleSmall: base.titleSmall?.copyWith(height: 1.4),
      // Body — 日本語本文は height 1.7 が最適
      bodyLarge: base.bodyLarge?.copyWith(height: 1.7),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.7),
      bodySmall: base.bodySmall?.copyWith(height: 1.6),
      // Label (チップ・ボタンラベル)
      labelLarge: base.labelLarge?.copyWith(height: 1.5),
      labelMedium: base.labelMedium?.copyWith(height: 1.5, letterSpacing: 0.5),
      labelSmall: base.labelSmall?.copyWith(height: 1.5),
    );
  }

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
      _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
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
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: _appFontFamily,
      fontFamilyFallback: _appFontFallback,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
    );
    return base.copyWith(
      textTheme: _buildJaTextTheme(base.textTheme),
      primaryTextTheme: _buildJaTextTheme(base.primaryTextTheme),
    );
  }

  ThemeData getDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: _appFontFamily,
      fontFamilyFallback: _appFontFallback,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF020617), // Very Dark Navy
        foregroundColor: Colors.white,
      ),
    );
    return base.copyWith(
      textTheme: _buildJaTextTheme(base.textTheme),
      primaryTextTheme: _buildJaTextTheme(base.primaryTextTheme),
    );
  }
}
