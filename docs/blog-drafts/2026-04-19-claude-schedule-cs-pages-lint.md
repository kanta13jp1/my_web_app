---
title: "Claude ScheduleがCSページを自動生成したらlintエラーが溜まった話 — 自動化の品質ゲート設計"
tags: ClaudeCode,Flutter,CI/CD,個人開発,buildinpublic
published: true
---

# Claude ScheduleがCSページを自動生成したらlintエラーが溜まった話

## 背景: Claude Schedule によるCS対応自動化

毎時間、Claude Code Schedule がカスタマーサポートチケットを確認し、
必要に応じて Flutter ページを自動生成する仕組みを運用している。

```yaml
# cs-check.yml (毎時実行)
on:
  schedule:
    - cron: '0 * * * *'
```

Claude が Dart コードを生成するとき、品質にばらつきが出る。
特に **trailing commas** と **deprecated API** は見落としやすい。

## 発生したエラーパターン

```
error - Missing a required trailing comma - lib\pages\leave_management_page.dart:76:8
error - 'value' is deprecated. Use initialValue instead - lib\pages\leave_management_page.dart:154:21
error - Missing a required trailing comma - lib\pages\performance_review_page.dart:82:8
error - Missing a required trailing comma - lib\pages\pomodoro_timer_page.dart:129:8
(計22件)
```

CS-check が 1 時間ごとにページを生成するため、修正前に複数セッション分の
エラーが積み重なっていた。

## 修正手順

```bash
# 1. dart fix で一括修正 (trailing commas)
dart fix --apply lib/

# 2. dart format で整形
dart format lib/pages/leave_management_page.dart \
            lib/pages/performance_review_page.dart \
            lib/pages/pomodoro_timer_page.dart

# 3. flutter analyze で確認
flutter analyze lib/
# → No issues found!
```

`dart fix --apply` は `require_trailing_commas` を自動修正できる。
`deprecated_member_use` (value → initialValue) は同時に修正された。

## 根本対策: CS-check WF に lint step を追加

Claude が Dart コードを生成した直後に自動で lint チェックを走らせる:

```yaml
# cs-check.yml に追加
- name: Lint generated Dart files
  if: steps.generate_page.outputs.dart_files != ''
  run: |
    dart fix --apply lib/
    dart format lib/ --set-exit-if-changed
    flutter analyze lib/
  continue-on-error: false  # lint エラーがあればコミットしない
```

`continue-on-error: false` にして、lint 失敗時はコミットをスキップする。

## DropdownButtonFormField の deprecated API 問題

Flutter 3.33 から `DropdownButtonFormField` の `value:` パラメータが deprecated:

```dart
// ❌ deprecated (Flutter 3.33+)
DropdownButtonFormField<String>(
  value: _selectedValue,
  ...
)

// ✅ 正しい
DropdownButtonFormField<String>(
  initialValue: _selectedValue,
  ...
)
```

AI が生成するコードは学習データが古いため、deprecated API を使い続ける。
Claude Code に対して **system prompt でバージョン制約を明示** するのが有効:

```markdown
# system prompt に追加
Flutter バージョン: 3.38
- DropdownButtonFormField: value → initialValue を使用
- 全引数末尾にカンマを追加 (require_trailing_commas 有効)
```

## まとめ

| 問題 | 対策 |
|------|------|
| trailing commas 漏れ | `dart fix --apply` + WF lint step |
| deprecated API (value→initialValue) | system prompt にバージョン制約記載 |
| エラー蓄積 | CS-check WF の lint step で即検出 |

自動生成コードは **生成直後に lint を通す** がベストプラクティス。
人間のコードレビューよりも CI/lint の方が漏れなく検出できる。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#ClaudeCode #Flutter #CI/CD #buildinpublic #個人開発
