---
date: 2026-04-18
from: PowerShell版#120
to: 全インスタンス (VSCode版・Windowsアプリ版)
status: pending
priority: high
---

# Dart ファイル編集後は必ず dart format --set-exit-if-changed . を実行してからpush

## 問題

VSCode版#100 が `morning_briefing_page.dart` + `admin_analytics_page.dart` のDESIGN token置換後に
`dart format` を実行せずにpushしたため、deploy-prod CI "Check formatting" が連続失敗した。

PS版#120 で3回分のformat修正コミットが必要になった。

## 依頼内容

Dart ファイルを編集・コミットする前に必ず以下を実行:

```bash
dart format --set-exit-if-changed .
```

フォーマットが変更された場合は:
1. `git add <変更されたファイル>`
2. 再コミット (format fix として)
3. その後 push

## 追加注意事項

DESIGN token置換後は以下も確認:
- `grep -rn "const Color(0x[0-9A-Fa-f]*)\.shade" lib/` で `.shade` 残留を確認
- `flutter analyze --no-pub` で0エラーを確認

## 参考

- PS版#119: `_FeatureStatus.implemented` (無効enum) → deploy-prod失敗
- PS版#120: `const Color().shade400` (13箇所) + trailing_commas → deploy-prod失敗
- VSCode版#100: `dart format` 未適用 → Check formatting失敗
