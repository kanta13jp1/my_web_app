import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeDef {
  final String code;
  final String nameJa;
  final String emoji;
  final Color previewPrimary;
  final Color previewAccent;
  final Color previewBg;
  final bool isDark;

  const AppThemeDef({
    required this.code,
    required this.nameJa,
    required this.emoji,
    required this.previewPrimary,
    required this.previewAccent,
    required this.previewBg,
    required this.isDark,
  });
}

class ThemeService extends ChangeNotifier {
  static const String _appFontFamily = 'NotoSansJP';
  static const List<String> _appFontFallback = <String>[
    'NotoSansJP',
    'NotoSans',
    'NotoColorEmoji',
  ];

  static const Color _lightBackground = Color(0xFFF5F7FA);
  static const Color _lightSurface = Colors.white;
  static const Color _lightSurfaceAlt = Color(0xFFF0F3F7);
  static const Color _lightText = Color(0xFF08131A);
  static const Color _lightTextMuted = Color(0xFF5C6B76);
  static const Color _lightBorder = Color(0x2208131A);

  static const Color _darkBackground = Color(0xFF0A0A0A);
  static const Color _darkSurface = Color(0xFF141A22);
  static const Color _darkSurfaceAlt = Color(0xFF1C2430);
  static const Color _darkText = Color(0xFFE7EDF3);
  static const Color _darkTextMuted = Color(0xFFA5B1BD);
  static const Color _darkBorder = Color(0x33FFFFFF);

  static const Color _accentOrange = Color(0xFFFF6B35);
  static const Color _accentOrangeSoft = Color(0xFFFF8C5A);
  static const Color _danger = Color(0xFFB22323);

  static TextTheme _buildJaTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(height: 1.3),
      displayMedium: base.displayMedium?.copyWith(height: 1.3),
      displaySmall: base.displaySmall?.copyWith(height: 1.35),
      headlineLarge: base.headlineLarge?.copyWith(
        height: 1.4,
        letterSpacing: 0.96,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        height: 1.4,
        letterSpacing: 0.72,
      ),
      headlineSmall: base.headlineSmall?.copyWith(height: 1.4),
      titleLarge: base.titleLarge?.copyWith(height: 1.4),
      titleMedium: base.titleMedium?.copyWith(height: 1.4),
      titleSmall: base.titleSmall?.copyWith(height: 1.4),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.7),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.7),
      bodySmall: base.bodySmall?.copyWith(height: 1.6),
      labelLarge: base.labelLarge?.copyWith(height: 1.5),
      labelMedium: base.labelMedium?.copyWith(height: 1.5),
      labelSmall: base.labelSmall?.copyWith(height: 1.5),
    );
  }

  static const List<AppThemeDef> catalog = [
    AppThemeDef(
      code: 'dark_ai',
      nameJa: '自分株式会社',
      emoji: '🌃',
      previewPrimary: Color(0xFFFF6B35),
      previewAccent: Color(0xFF3949AB),
      previewBg: Color(0xFF0A0A0A),
      isDark: true,
    ),
    AppThemeDef(
      code: 'minimal_mono',
      nameJa: 'ミニマル',
      emoji: '⚫',
      previewPrimary: Color(0xFF000000),
      previewAccent: Color(0xFF0066FF),
      previewBg: Color(0xFFFFFFFF),
      isDark: false,
    ),
    AppThemeDef(
      code: 'saas_blue',
      nameJa: 'SaaSブルー',
      emoji: '🟦',
      previewPrimary: Color(0xFF2864F0),
      previewAccent: Color(0xFFFF7849),
      previewBg: Color(0xFFF8FAFC),
      isDark: false,
    ),
    AppThemeDef(
      code: 'retro_skeu',
      nameJa: 'レトロ',
      emoji: '🎞',
      previewPrimary: Color(0xFF3B5998),
      previewAccent: Color(0xFF8B9DC3),
      previewBg: Color(0xFFE8ECF0),
      isDark: false,
    ),
    AppThemeDef(
      code: 'nature_calm',
      nameJa: 'ネイチャー',
      emoji: '🌿',
      previewPrimary: Color(0xFF4CAF50),
      previewAccent: Color(0xFF81C784),
      previewBg: Color(0xFFF1F8E9),
      isDark: false,
    ),
    AppThemeDef(
      code: 'note_warm',
      nameJa: 'note.com',
      emoji: '📝',
      previewPrimary: Color(0xFF5AC8B8),
      previewAccent: Color(0xFFFF6B35),
      previewBg: Color(0xFFFFFFFF),
      isDark: false,
    ),
    AppThemeDef(
      code: 'freee_blue',
      nameJa: 'freee',
      emoji: '💼',
      previewPrimary: Color(0xFF2864F0),
      previewAccent: Color(0xFFFF7849),
      previewBg: Color(0xFFF5F7FA),
      isDark: false,
    ),
    AppThemeDef(
      code: 'smarthr_corp',
      nameJa: 'SmartHR',
      emoji: '🏢',
      previewPrimary: Color(0xFF0077C7),
      previewAccent: Color(0xFFFF7849),
      previewBg: Color(0xFFFFFFFF),
      isDark: false,
    ),
    AppThemeDef(
      code: 'apple_clean',
      nameJa: 'Apple',
      emoji: '🍎',
      previewPrimary: Color(0xFF000000),
      previewAccent: Color(0xFF007AFF),
      previewBg: Color(0xFFF5F5F7),
      isDark: false,
    ),
    AppThemeDef(
      code: 'wired_bold',
      nameJa: 'WIRED',
      emoji: '⚡',
      previewPrimary: Color(0xFFFFFF00),
      previewAccent: Color(0xFFFFFF00),
      previewBg: Color(0xFF000000),
      isDark: true,
    ),
  ];

  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = const Color(0xFF0F172A);
  String _selectedThemeCode = 'dark_ai';
  ThemeData? _overrideTheme;

  ThemeService() {
    _loadThemeMode();
  }

  ThemeMode getFlutterThemeMode() => _themeMode;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Color get primaryColor => _primaryColor;
  String get selectedThemeCode => _selectedThemeCode;
  ThemeData? get overrideTheme => _overrideTheme;

  static const Color roleCso = Color(0xFF475569);
  static const Color roleCfo = Color(0xFF0D9488);
  static const Color roleCho = Color(0xFF166534);
  static const Color roleCmo = Color(0xFF7E22CE);
  static const Color roleChro = Color(0xFFBE185D);
  static const Color roleCko = Color(0xFF4338CA);

  void toggleTheme() {
    setThemeMode(
      _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString());
  }

  void setPrimaryColor(Color color) {
    _primaryColor = color;
    notifyListeners();
  }

  Future<void> _loadThemeMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? themeString = prefs.getString('theme_mode');
    if (themeString != null) {
      if (themeString == 'ThemeMode.light') _themeMode = ThemeMode.light;
      if (themeString == 'ThemeMode.dark') _themeMode = ThemeMode.dark;
      if (themeString == 'ThemeMode.system') _themeMode = ThemeMode.system;
    }
    final String? savedCode = prefs.getString('catalog_theme_code');
    if (savedCode != null && savedCode != 'dark_ai') {
      _selectedThemeCode = savedCode;
      final def = catalog.firstWhere(
        (d) => d.code == savedCode,
        orElse: () => catalog.first,
      );
      _overrideTheme = _buildCatalogTheme(def);
    }
    notifyListeners();
  }

  Future<void> applyThemeByCode(String code) async {
    _selectedThemeCode = code;
    if (code == 'dark_ai') {
      _overrideTheme = null;
    } else {
      final def = catalog.firstWhere(
        (d) => d.code == code,
        orElse: () => catalog.first,
      );
      _overrideTheme = _buildCatalogTheme(def);
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('catalog_theme_code', code);
    notifyListeners();
  }

  ThemeData _buildCatalogTheme(AppThemeDef def) {
    final brightness = def.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: def.previewPrimary,
      brightness: brightness,
    ).copyWith(
      primary: def.previewPrimary,
      secondary: def.previewAccent,
      surface:
          def.isDark ? def.previewBg.withValues(alpha: 0.9) : def.previewBg,
      onSurface: def.isDark ? const Color(0xFFE7EDF3) : const Color(0xFF08131A),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _appFontFamily,
      fontFamilyFallback: _appFontFallback,
      scaffoldBackgroundColor: def.previewBg,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            def.code == 'minimal_mono' || def.code == 'apple_clean' ? 20 : 12,
          ),
        ),
      ),
    );
  }

  ThemeData getLightTheme() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: _primaryColor,
      secondary: _accentOrange,
      surface: _lightSurface,
      onSurface: _lightText,
      outline: _lightBorder,
      error: _danger,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: _appFontFamily,
      fontFamilyFallback: _appFontFallback,
      scaffoldBackgroundColor: _lightBackground,
      cardColor: _lightSurface,
      dividerColor: _lightBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightSurface,
        foregroundColor: _lightText,
        elevation: 0,
        centerTitle: false,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: _appFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1.4,
          color: _lightText,
        ),
      ),
    );

    return base.copyWith(
      textTheme: _buildJaTextTheme(base.textTheme).apply(
        bodyColor: _lightText,
        displayColor: _lightText,
      ),
      primaryTextTheme: _buildJaTextTheme(base.primaryTextTheme),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _lightBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accentOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: _appFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightText,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: _lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _accentOrange,
          minimumSize: const Size(0, 44),
          textStyle: const TextStyle(
            fontFamily: _appFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurfaceAlt,
        hintStyle: const TextStyle(color: _lightTextMuted, height: 1.5),
        labelStyle: const TextStyle(color: _lightTextMuted, height: 1.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accentOrange, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightText,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: _appFontFamily,
          height: 1.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _accentOrange,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: _lightSurfaceAlt,
        selectedColor: _accentOrange.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: _lightBorder),
        ),
        labelStyle: const TextStyle(
          color: _lightText,
          fontFamily: _appFontFamily,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _lightBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurface,
        indicatorColor: _accentOrange.withValues(alpha: 0.14),
        labelTextStyle: const WidgetStatePropertyAll<TextStyle>(
          TextStyle(
            fontFamily: _appFontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  ThemeData getDarkTheme() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _accentOrangeSoft,
      secondary: _accentOrange,
      surface: _darkSurface,
      onSurface: _darkText,
      outline: _darkBorder,
      error: _danger,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: _appFontFamily,
      fontFamilyFallback: _appFontFallback,
      scaffoldBackgroundColor: _darkBackground,
      cardColor: _darkSurface,
      dividerColor: _darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: _darkText,
        elevation: 0,
        centerTitle: false,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: _appFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1.4,
          color: _darkText,
        ),
      ),
    );

    return base.copyWith(
      textTheme: _buildJaTextTheme(base.textTheme).apply(
        bodyColor: _darkText,
        displayColor: _darkText,
      ),
      primaryTextTheme: _buildJaTextTheme(base.primaryTextTheme),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _darkBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accentOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: _appFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkText,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: _darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _accentOrangeSoft,
          minimumSize: const Size(0, 44),
          textStyle: const TextStyle(
            fontFamily: _appFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceAlt,
        hintStyle: const TextStyle(color: _darkTextMuted, height: 1.5),
        labelStyle: const TextStyle(color: _darkTextMuted, height: 1.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accentOrange, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurfaceAlt,
        contentTextStyle: const TextStyle(
          color: _darkText,
          fontFamily: _appFontFamily,
          height: 1.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _accentOrangeSoft,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: _darkSurfaceAlt,
        selectedColor: _accentOrange.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: _darkBorder),
        ),
        labelStyle: const TextStyle(
          color: _darkText,
          fontFamily: _appFontFamily,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkSurface,
        indicatorColor: _accentOrange.withValues(alpha: 0.16),
        labelTextStyle: const WidgetStatePropertyAll<TextStyle>(
          TextStyle(
            fontFamily: _appFontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
