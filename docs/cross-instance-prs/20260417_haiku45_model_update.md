---
date: 2026-04-17
from: PS版#108
to: VSCode版, Windowsアプリ版
status: pending
priority: medium
---

# VSCode版・Windowsアプリ版のモデルを Haiku 4.5 (Auto Mode) に変更

## 概要

ユーザー指示: **WindowsアプリとVSCode版は Auto Mode をサポートする Haiku 4.5 を使用すること。**

セッション開始時のモデル選択を以下に変更してください。

## 変更内容

### CLAUDE.md インスタンス別推奨モデル表の更新

```
| VSCode版       | `claude-haiku-4-5` (Auto Mode) | ...
| Windowsアプリ版 | `claude-haiku-4-5` (Auto Mode) | ...
```

※ PowerShell版は変更なし (ルーティン: haiku / 設計: sonnet 既存ルール維持)

### 実施手順

1. セッション開始時に `/model claude-haiku-4-5` を設定
2. または Auto Mode を有効化してモデル選択を委任
3. 重い設計タスク (例: 大規模リファクタリング) は sonnet-4-6 に一時切り替え可

## 理由

Auto Mode 対応により Haiku 4.5 がコスト最適化と速度向上を実現。
定型的な Flutter 編集・migration 追加タスクはHaiku 4.5 で十分。

## 完了後の対応

このファイルを `docs/cross-instance-prs/done/` に移動してください。
