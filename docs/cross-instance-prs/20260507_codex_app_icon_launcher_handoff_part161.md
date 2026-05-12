# Codex hand-off: アプリアイコン実装 + flutter_launcher_icons 設定

**作成**: Win Claude / Win版#132 part 161 / 2026-05-07  
**期限**: 2026-05-25  
**Issue**: [#1495](https://github.com/kanta13jp1/my_web_app/issues/1495) Phase 0 Mobile Release  
**Priority**: high  

---

## 概要

Win Claude が設計・生成したアプリアイコン (1024×1024 PNG) を iOS/Android に適用する。  
`flutter_launcher_icons` + `flutter_native_splash` パッケージで自動生成。

---

## 成果物 (= Win Claude 完了済)

| ファイル | 内容 |
|---------|------|
| `assets/icons/app_icon.png` | 1024×1024 PNG マスターアイコン (iOS App Store 用) |
| `assets/icons/app_icon_foreground.png` | Android Adaptive Icon 前景層 (75% safe zone padding 済 / 透過背景) |

**デザイン仕様**:
- 背景: ダーク (#0A0A0A)
- メインシンボル: オレンジ (#FF6B35) ダイヤモンド形状 + グロー
- 背景テクスチャ: インディゴ (#3D5AFE) AI 回路パターン
- ブランド: 自分株式会社 / プロフェッショナルダーク × 生命力オレンジ

---

## Codex 実装タスク

### Step 1: pubspec.yaml に dev_dependencies 追加

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.1
  flutter_native_splash: ^2.4.1
```

### Step 2: pubspec.yaml に flutter_launcher_icons 設定追加

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/app_icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#0A0A0A"
  adaptive_icon_foreground: "assets/icons/app_icon_foreground.png"
  remove_alpha_ios: true
  web:
    generate: false
```

### Step 3: pubspec.yaml に flutter_native_splash 設定追加

```yaml
flutter_native_splash:
  color: "#0A0A0A"
  image: "assets/icons/app_icon.png"
  color_dark: "#0A0A0A"
  image_dark: "assets/icons/app_icon.png"
  android_12:
    image: "assets/icons/app_icon_foreground.png"
    color: "#0A0A0A"
    icon_background_color: "#0A0A0A"
  fullscreen: false
```

### Step 4: パッケージ取得 + アイコン生成

```bash
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### Step 5: 生成ファイル確認

- `android/app/src/main/res/mipmap-*/ic_launcher.png` (各サイズ)
- `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png`
- `android/app/src/main/res/drawable/ic_launcher_background.xml` (色指定)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (全サイズ)
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/` (スプラッシュ)

### Step 6: web/icons/ の更新 (= Flutter Web 用)

```bash
# flutter_launcher_icons は web: generate: false なので手動で更新
# 既存の web/icons/Icon-192.png / Icon-512.png は PWA 用
# デザイン一貫性のため手動更新推奨 (optional)
```

---

## 受け入れ条件 (= 7 項目)

1. [ ] `flutter pub get` がエラーなし
2. [ ] `dart run flutter_launcher_icons` が exit 0
3. [ ] `dart run flutter_native_splash:create` が exit 0
4. [ ] Android mipmap-xxxhdpi/ic_launcher.png が 192x192 以上
5. [ ] iOS AppIcon.appiconset/Icon-App-1024x1024@1x.png が差し替え済
6. [ ] `flutter build apk --debug` が exit 0 (= 基本ビルド検証)
7. [ ] `flutter build ios --debug --no-codesign` が exit 0

---

## 注意事項

- `remove_alpha_ios: true` 必須 (= iOS は alpha 非対応 / 白背景になるのを防ぐ)
- `adaptive_icon_background` は色指定 (= 画像不要)
- `flutter_launcher_icons ^0.14.x` は `dart run` 形式 (= `flutter pub run` 非推奨)
- 実行前に `flutter pub get` でキャッシュクリア推奨
- [EF-CAP-50] 本タスクは EF 変更なし (= pubspec + assets のみ)

---

## 関連 docs

- [`docs/MOBILE_RELEASE_SPEC.md`](../MOBILE_RELEASE_SPEC.md) §6 hand-off matrix
- [`docs/DESIGN.md`](../DESIGN.md) デザイントークン
- [`assets/icons/app_icon.png`](../../assets/icons/app_icon.png) マスターアイコン
- [Issue #1495](https://github.com/kanta13jp1/my_web_app/issues/1495)

---

*Win版#132 part 161 / 2026-05-07 / Win Claude design-skills 完了 → Win Codex 実装 hand-off*
