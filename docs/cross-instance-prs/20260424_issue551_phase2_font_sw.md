# cross-instance-pr: Issue #551 Phase 2/3 — フォント堅牢化 + SW 改善

**from**: PS版#5 (on-call)
**to**: VSCode版
**date**: 2026-04-24
**priority**: high
**deadline**: 2026-05-01
**issue**: #551

## 背景

Issue #551 `ERR_INSUFFICIENT_RESOURCES` の根本原因の一つが **Google Fonts CDN 動的 fetch**。
Phase 1 (AppLifecycleState heartbeat 停止 / commit d9cfbb49) は実施済み。
Phase 2/3 はフロントエンド修正のため VSCode版 に依頼。

## Phase 2: フォント読み込みの堅牢化

### 選択肢 A — google_fonts パッケージの runtime fetch 無効化 (推奨・最小変更)

```dart
// lib/main.dart の runApp() 前に追加
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;  // ← 追加
  // ... existing init ...
}
```

事前ダウンロード:
```bash
flutter pub add google_fonts
dart run google_fonts:downloader
# → assets/google_fonts/ に .ttf が生成される
```

pubspec.yaml に追記:
```yaml
flutter:
  assets:
    - assets/google_fonts/
```

### 選択肢 B — pubspec.yaml に直接 Noto Sans JP を同梱

```yaml
flutter:
  fonts:
    - family: NotoSansJP
      fonts:
        - asset: assets/fonts/NotoSansJP-Regular.otf
          weight: 400
        - asset: assets/fonts/NotoSansJP-Bold.otf
          weight: 700
```

フォントファイルは https://fonts.google.com/specimen/Noto+Sans+JP からダウンロード
(Regular + Bold subset で約 400KB)

## Phase 3: Service Worker 初期化の改善

`web/flutter_service_worker.js` (または `web/index.html` の SW 登録部分) を確認し:

1. **プリフェッチ対象を削減**: `RESOURCES` リストから大きな画像や未使用 EF URL を除外
2. **タイムアウト緩和**: SW activate タイムアウトを 4s → 10s に設定 (flutter_web_service_worker の設定による)

具体的には `web/index.html` の:
```javascript
if ('serviceWorker' in navigator) {
  window.addEventListener('flutter-first-frame', function () {
    navigator.serviceWorker.register('flutter_service_worker.js');
  });
}
```

を確認し、activate 失敗時のフォールバックを追加:
```javascript
navigator.serviceWorker.register('flutter_service_worker.js')
  .catch(err => console.warn('SW registration failed, continuing without SW:', err));
```

## 受け入れ条件

- [ ] `GoogleFonts.config.allowRuntimeFetching = false` or フォント同梱 → fonts.gstatic.com へのランタイム fetch ゼロ
- [ ] DevTools Network で Noto Sans JP が CDN ではなくアプリバンドルから読み込まれる
- [ ] `flutter analyze` 0 エラー / `dart format` 適用済み
- [ ] 本番で Console に「Could not find a set of Noto fonts」が出ない

## ✅ 完了 (VSCode版 S3 2026-04-24)

- commit: fca97103
- Phase 2: `GoogleFonts.config.allowRuntimeFetching = false` + import 追加 (lib/main.dart)
- Phase 3: `unhandledrejection` SW fallback handler (web/index.html)
- dart format: 0 changes / flutter analyze: 0 issues

## 参考

- Issue #551 本文の Phase 2/3 セクション
- Phase 1 実施済み commit: d9cfbb49 (growth_mission_service.dart AppLifecycleState)
- Phase 4 (EF 呼び出し統合) は別途 PS#1 or VSCode版 に依頼予定
