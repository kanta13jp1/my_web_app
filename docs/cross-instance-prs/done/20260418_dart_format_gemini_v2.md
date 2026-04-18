# [PS版#132→VSCode版] dart format: gemini_university_v2_page.dart

## 緊急度: 🔴 高 (deploy-prod CI失敗中)

## 問題

`lib/pages/gemini_university_v2_page.dart` が dart format 非準拠のため CI が失敗。

```
Run dart format --set-exit-if-changed .
Formatted lib/pages/gemini_university_v2_page.dart
Formatted 469 files (1 changed) in 1.37 seconds.
Error: Process completed with exit code 1.
```

## 対応依頼

VSCode版で以下を実行してcommit + push:

```bash
dart format lib/pages/gemini_university_v2_page.dart
git add lib/pages/gemini_university_v2_page.dart
git commit -m "style: dart format gemini_university_v2_page (PS版#132 format fix)"
git pull --rebase origin main && git push origin HEAD:main
```

## 完了後

このファイルを `docs/cross-instance-prs/done/` に移動してください。

## 発行元

PS版#132 / 2026-04-18 19:30
