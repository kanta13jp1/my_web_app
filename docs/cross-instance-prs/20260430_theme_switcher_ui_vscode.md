# Cross-Instance PR: テーマ切り替え UI + ThemeData mapping

**作成**: Win版#132 part 100 / 2026-04-30
**FROM**: Win版 (User 要望 + schema 設計)
**TO**: VSCode版 (Flutter UI 専任 territory)
**優先度**: HIGH
**期限**: 2026-05-07 (1 週間)
**親軸**: テーマ切り替え機能 + INDIE_DEV_VELOCITY #5 (Hand-Written Art)

---

## 1. 背景

User 要望: 「テーマ切り替え機能で複数の様々な画面デザインを選択できる機能を追加したい」 (= 4 reference image 添付).

Win territory done (= phase 1 / part 100):
- 設計 doc: `docs/THEME_SWITCHER_DESIGN.md`
- migration `20260430080000_create_app_themes.sql`:
  - `app_themes` (catalog) テーブル新規
  - `user_theme_preferences` (= ユーザー選択 / RLS 自身のみ) 新規
  - 10 theme seed (= 自分株式会社 default + 4 reference image + 5 既存 design system)

VSCode territory (= phase 2 / 本 PR):
- Flutter UI で **theme selector page + ThemeData mapping + Provider state mgmt**

## 2. 期待する実装

### 2.1 Theme selector page (= 新規 / `/settings/theme`)

```
┌──────────────────────────────────────────┐
│  ← 戻る  🎨 テーマを選ぶ                │
├──────────────────────────────────────────┤
│  現在のテーマ: 🌃 自分株式会社 default     │
│                                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ preview  │ │ preview  │ │ preview  │ │
│  │ ⚫️       │ │ 🟦       │ │ 🌿       │ │
│  │ minimal  │ │ saas blue│ │ nature   │ │
│  │ mono     │ │          │ │ calm     │ │
│  └──────────┘ └──────────┘ └──────────┘ │
│  (= 10 theme grid / preview tile / tap = 即適用)  │
└──────────────────────────────────────────┘
```

各 tile = preview image + theme_code label + 「適用」button.

### 2.2 ThemeData mapping function

`lib/utils/app_theme_factory.dart` 新規:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemeFactory {
  static Color _hex(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  static ThemeData fromRow(Map<String, dynamic> row) {
    final brightness = row['brightness'] == 'dark' ? Brightness.dark : Brightness.light;
    final primary = _hex(row['primary_color']);
    final accent = _hex(row['accent_color']);
    final radius = (row['border_radius'] as num? ?? 8).toDouble();
    final fontJa = row['font_family_ja'] as String? ?? 'Noto Sans JP';

    return ThemeData(
      brightness: brightness,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        secondary: accent,
        surface: _hex(row['surface_color']),
      ),
      scaffoldBackgroundColor: _hex(row['background_color']),
      textTheme: GoogleFonts.getTextTheme(fontJa, ThemeData(brightness: brightness).textTheme).apply(
        bodyColor: _hex(row['text_color']),
        displayColor: _hex(row['text_color']),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  static ThemeData defaultTheme() {
    // フォールバック (= dark_ai 互換)
    return fromRow({
      'brightness': 'dark',
      'primary_color': '#FF6B35',
      'accent_color': '#3949AB',
      'background_color': '#0A0A0A',
      'surface_color': '#1A1A1A',
      'text_color': '#FAFAFA',
      'font_family_ja': 'Noto Sans JP',
      'border_radius': 8,
    });
  }
}
```

### 2.3 Provider state management

`lib/providers/theme_provider.dart` 新規:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _currentTheme = AppThemeFactory.defaultTheme();
  String _currentThemeCode = 'dark_ai';
  ThemeData get currentTheme => _currentTheme;
  String get currentThemeCode => _currentThemeCode;

  Future<void> loadFromPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('theme_code');
    if (code != null) {
      await applyByCode(code);
    } else {
      // 認証済なら DB から読込
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await _loadFromSupabase();
      }
    }
  }

  Future<void> _loadFromSupabase() async {
    final res = await Supabase.instance.client.functions.invoke(
      'ai-hub',
      body: {'action': 'app.theme.get_preference'},
    );
    final data = res.data as Map?;
    final themeCode = data?['theme_code'] as String?;
    if (themeCode != null) {
      await applyByCode(themeCode);
    }
  }

  Future<void> applyByCode(String code) async {
    final res = await Supabase.instance.client.functions.invoke(
      'ai-hub',
      body: {'action': 'app.theme.list'},
    );
    final list = (res.data as Map?)?['themes'] as List? ?? [];
    final row = list.firstWhere(
      (e) => (e as Map)['theme_code'] == code,
      orElse: () => null,
    );
    if (row != null) {
      _currentTheme = AppThemeFactory.fromRow(row as Map<String, dynamic>);
      _currentThemeCode = code;

      // 永続化
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_code', code);

      // 認証済なら DB へも保存
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.functions.invoke(
          'ai-hub',
          body: {'action': 'app.theme.set_preference', 'theme_code': code},
        );
      }

      notifyListeners();
    }
  }
}
```

### 2.4 main.dart 統合

```dart
return ChangeNotifierProvider(
  create: (_) => ThemeProvider()..loadFromPreference(),
  child: Consumer<ThemeProvider>(
    builder: (context, themeProvider, _) => MaterialApp(
      theme: themeProvider.currentTheme,
      // ...
    ),
  ),
);
```

### 2.5 settings menu integration

既存 settings page (= `/settings`) に「🎨 テーマ」entry 追加 → `/settings/theme` へ遷移.

## 3. 受入基準

- [ ] `lib/pages/theme_selector_page.dart` 新規 (= 10 theme grid + preview)
- [ ] `lib/utils/app_theme_factory.dart` 新規 (= ThemeData mapping)
- [ ] `lib/providers/theme_provider.dart` 新規 (= state mgmt + 永続化)
- [ ] `main.dart` ChangeNotifierProvider + theme apply 統合
- [ ] settings menu entry 追加
- [ ] route 追加: `/settings/theme`
- [ ] integration test (`integration_test/theme_switcher_test.dart`):
  - LP → settings → theme → minimal_mono 選択 → アプリ全体に theme 適用確認
- [ ] flutter analyze 0 issues
- [ ] cross-instance-pr 完了時 `done/` 移動

## 4. 並行 PR

- Codex#2: ai-hub に `app.theme.list / get_preference / set_preference` 3 actions (= 本 PR の前提)

## 5. shared_preferences 既存利用箇所

`lib/pages/project_gantt_page.dart` (= part 83 column resize) で既に shared_preferences 使用. 同型 pattern で theme_code 保存可能.

---

*Win版#132 part 100 / 2026-04-30 起票 / テーマ切り替え UI / Win → VSCode lane*
