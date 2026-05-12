# テーマ切り替え機能 設計

> **ソース**: User 要望 (2026-04-30 / Win版#132 part 100):
> > 「テーマ切り替え機能で複数の様々な画面デザインを選択できるような機能を追加したい」
>
> 4 reference image (= minimal mono / saas blue / retro skeuomorphic / nature gradient) + 既存 5 design system (note / freee / smarthr / apple / wired) を統合したテーマカタログ.

---

## 現状

- 既存 design = `docs/DESIGN.md` (= Orange + Indigo dark theme / 1 種固定)
- 既存 design system docs = note.com / freee / SmartHR / Apple JP / WIRED.jp / template (= 6 reference として保持)
- ユーザー側 customization = 不在
- ThemeData = lib/main.dart ハードコード

= **「1 アプリ = 1 ブランド」** 思想だったが、User 拡張で **「ユーザーが選べる」** 方向に進化.

---

## 設計

### コンセプト

```
[App Theme Catalog (= app_themes table)]
  └─ theme 1: 自分株式会社 default (Orange + Indigo dark)
  └─ theme 2: minimal mono (= image 1 / 黒白ミニマル)
  └─ theme 3: saas blue (= image 2 / SaaS productivity)
  └─ theme 4: retro skeuomorphic (= image 3 / レトロ立体感)
  └─ theme 5: nature calm (= image 4 / nature gradient)
  └─ theme 6: note.com (= teal warm reading)
  └─ theme 7: freee (= 4px grid blue)
  └─ theme 8: SmartHR (= Yu Gothic 8px grid)
  └─ theme 9: Apple JP (= SF Pro pill button)
  └─ theme 10: WIRED bold (= 黒×黄 palt)

[User Preference (= user_theme_preferences table)]
  └─ user_id ↔ theme_id (= 1 user 1 theme)
  └─ custom_overrides (= 将来の局所カスタマイズ用 jsonb)
```

= **10 theme catalog + ユーザーごと選択** の構造.

### 4 reference image マッピング

| image | theme_code | 特徴 |
| --- | --- | --- |
| 1 (黒白ミニマル / 円形 accent) | `minimal_mono` | brightness=light / primary=#000 / accent=#0066FF / radius=24 / font=Inter |
| 2 (SaaS blue dashboard / clean) | `saas_blue` | brightness=light / primary=#2864F0 / accent=#FF7849 / radius=8 / font=Noto Sans JP |
| 3 (retro skeuomorphic / search heavy) | `retro_skeu` | brightness=light / primary=#3B5998 / shadow heavy / radius=4 / font=Yu Gothic |
| 4 (nature gradient / 緑) | `nature_calm` | brightness=light / primary=#4CAF50 / accent=#81C784 / gradient bg / radius=16 / font=Noto Sans JP |

### 既存 design system マッピング

`docs/design-systems/` の既存 docs を活用:

| docs | theme_code | 特徴 |
| --- | --- | --- |
| note/DESIGN.md | `note_warm` | teal #5ac8b8 / line-height 2.0 / 620px reading width |
| freee/DESIGN.md | `freee_blue` | #2864F0 / 4px grid / system font |
| smarthr/DESIGN.md | `smarthr_corp` | #0077C7 / Yu Gothic Medium→400 / 8px grid |
| apple/DESIGN.md | `apple_clean` | SF Pro JP / pill button / #1d1d1f |
| wired/DESIGN.md | `wired_bold` | 黒×黄 / palt / 角張りデザイン |

### 自分株式会社 default

| theme_code | 特徴 |
| --- | --- |
| `dark_ai` (= default) | Orange #FF6B35 + Indigo #3949AB / dark / 既存 docs/DESIGN.md |

---

## DB schema

### `app_themes` (= テーマカタログ)

```sql
CREATE TABLE IF NOT EXISTS app_themes (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  theme_code        text NOT NULL UNIQUE,
  name_ja           text NOT NULL,
  name_en           text NOT NULL,
  description       text,
  emoji             text,
  brightness        text NOT NULL DEFAULT 'dark', -- 'light' | 'dark'
  primary_color     text NOT NULL,                -- hex '#FF6B35'
  accent_color      text NOT NULL,
  background_color  text NOT NULL,
  surface_color     text NOT NULL,
  text_color        text NOT NULL,
  font_family_ja    text,                          -- 'Noto Sans JP' | 'Yu Gothic' | etc
  font_family_en    text,                          -- 'Inter' | 'SF Pro' | etc
  border_radius     int  NOT NULL DEFAULT 8,
  letter_spacing    real NOT NULL DEFAULT 0,
  line_height       real NOT NULL DEFAULT 1.7,
  preview_image_url text,                          -- 公開 preview image
  reference_url     text,                          -- 元 design system へのリンク
  is_premium        boolean NOT NULL DEFAULT false,
  is_active         boolean NOT NULL DEFAULT true,
  sort_order        int NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
```

### `user_theme_preferences` (= ユーザー選択)

```sql
CREATE TABLE IF NOT EXISTS user_theme_preferences (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL,
  theme_id         uuid NOT NULL REFERENCES app_themes(id),
  custom_overrides jsonb,                          -- 将来の上書き用
  applied_at       timestamptz NOT NULL DEFAULT now(),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);
```

= **未認証ユーザー** = `localStorage` (Flutter `shared_preferences`) で theme_code 保持. 認証後に DB へ migration.

### RLS

```sql
-- app_themes: 全 user 閲覧可
ALTER TABLE app_themes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "app_themes_select_all" ON app_themes
  FOR SELECT USING (is_active = true);

-- user_theme_preferences: 自身のみ
ALTER TABLE user_theme_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_theme_preferences_select_own" ON user_theme_preferences
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "user_theme_preferences_insert_own" ON user_theme_preferences
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_theme_preferences_update_own" ON user_theme_preferences
  FOR UPDATE USING (auth.uid() = user_id);
```

---

## UI 設計 (= VSCode territory)

### theme selector page (= 新規 / `/settings/theme`)

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
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ retro    │ │ note.com │ │ freee    │ │
│  │ skeu     │ │ warm     │ │ blue     │ │
│  └──────────┘ └──────────┘ └──────────┘ │
│  ...                                     │
└──────────────────────────────────────────┘
```

= 10 theme grid / preview image 付 / tap = apply (= live preview).

### Live preview

theme tap → instant ThemeData 切替 → 全画面再描画.

### apply 永続化

- 認証済 = ai-hub `app.theme.set_preference` 経由 DB INSERT/UPDATE
- 未認証 = `shared_preferences` で `theme_code` のみ保存

### settings menu integration

```
Settings page
  └─ アカウント
  └─ 通知
  └─ 🎨 テーマ      ← 新規 entry
  └─ 言語
  └─ ...
```

---

## EF API (= ai-hub action / Codex#2 territory)

新 actions:

| action | 用途 |
| --- | --- |
| `app.theme.list` | 全 active theme catalog 取得 |
| `app.theme.get_preference` | current user の theme preference 取得 |
| `app.theme.set_preference` | user の theme 設定 |

= ai-hub action 追加のみ / EF 数増加なし.

---

## ThemeData mapping (= Flutter / VSCode territory)

各 `app_themes` row の color / font / radius を Flutter `ThemeData` にマップ:

```dart
ThemeData appThemeFromRow(Map<String, dynamic> row) {
  final brightness = row['brightness'] == 'dark' ? Brightness.dark : Brightness.light;
  return ThemeData(
    brightness: brightness,
    primaryColor: parseHex(row['primary_color']),
    colorScheme: ColorScheme.fromSeed(
      seedColor: parseHex(row['primary_color']),
      brightness: brightness,
    ),
    textTheme: GoogleFonts.getTextTheme(row['font_family_ja'] ?? 'Noto Sans JP'),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular((row['border_radius'] as num).toDouble()),
      ),
    ),
    // ...
  );
}
```

---

## 実装 phase 配分

| phase | territory | 内容 |
| --- | --- | --- |
| 1 | **Win** (本 part 100) | schema migration (= 2 テーブル + 10 theme seed) + 設計 doc |
| 2 | **VSCode** (cross-instance-pr) | theme selector page + ThemeData mapping + Provider state mgmt |
| 3 | **Codex#2** (cross-instance-pr) | ai-hub に `app.theme.list / get_preference / set_preference` 3 actions |
| 4 | **VSCode / Win** (= 必要時) | preview image 撮影 + Firebase Storage 公開 |

---

## INDIE_DEV_VELOCITY 原則 cross-ref

- **#5 Hand-Written Code as Art**: 10 theme catalog 設計 = CEO 直筆判断 (= AI 単独では選定不能な美的選択)
- **#6 Avoid Side-Project Graveyard**: User 直接要望 → audience 確実
- **#7 Community Engagement**: 5 既存 design system reference を再活用 = community 接続点

---

## ROADMAP next steps

1. **本 doc + migration commit** (= Win版#132 part 100 / 100 part milestone)
2. cross-instance-pr → VSCode (theme selector UI / ThemeData mapping / Provider)
3. cross-instance-pr → Codex#2 (ai-hub 3 actions)
4. Phase 4: preview image 撮影 (= 後続 part)

---

*Win版#132 part 100 / 2026-04-30 / テーマ切り替え機能 設計 / 10 theme catalog / 100 part milestone*
