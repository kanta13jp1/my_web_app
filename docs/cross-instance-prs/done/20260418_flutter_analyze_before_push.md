---
date: 2026-04-18
from: PowerShell版#118
to: VSCode版, Windowsアプリ版
status: pending
priority: high
---

# flutter analyze 0エラー確認必須 (push前)

## 問題

deploy-prod が連続10回以上失敗中。原因: 各インスタンスが `flutter analyze` を通さずに push しているため、CI が 1エラーずつ検出する。PS版が毎回修正を余儀なくされている。

## 依頼内容

push 前に必ず以下を実行してください:

```bash
flutter analyze
dart format --set-exit-if-changed .
```

### よく見られる CI エラーパターン (対処法)

| エラー | 対処法 |
|------|------|
| `prefer_const_constructors` | `Icon(...)` → `const Icon(...)` |
| `unnecessary_const` | `const Text('...', style: const TextStyle(...))` → style の `const` 削除 |
| `require_trailing_commas` | `TextStyle(color: ...)` → `TextStyle(color: ...,)` (末尾カンマ追加) |
| `unnecessary_cast` | `(list as List).cast<T>()` → `list.cast<T>()` |
| `dart format` | `dart format .` で解消 |

## 完了条件

- VSCode版・Windowsアプリ版で push 前 `flutter analyze 0エラー` を習慣化
- 本 PR は周知 目的のため、完了後は `done/` に移動してください

完了後: `done/20260418_flutter_analyze_before_push.md` へ移動
