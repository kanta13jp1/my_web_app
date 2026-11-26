---
title: Image Assistant CLI Automated Image Pipeline Evaluation (Fit & Gap)
last_reviewed: 2026-11-26
review_cycle_days: 90
related_issue: 2798
---

# Image Assistant CLI イメージ更新自動化パイプライン評価 (#2798)

## 1. 現行 `my_web_app` との Fit & Gap 分析

| 評価項目 | 現行スタック (`my_web_app`) | Image Assistant CLI 構成 | Fit / Gap |
|---|---|---|---|
| **配信形態** | Flutter Web (CanvasKit) + Firebase Hosting | Windows デスクトップアプリ仮想配信 (Amazon WorkSpaces Applications / 旧 AppStream 2.0) | **Gap**: 現行は Web 配信であり、デスクトップ配布バイナリ導入時のみ対象 |
| **ビルド前検証** | GitHub Actions CI + SHA-256 検証 | インストーラー配置 (S3) + マニフェスト/チェックサム検証 | **Fit**: `scripts/image_pipeline_manifest_check.py` で事前 dry-run 検証可能 |
| **ロールアウト通知** | `deploy-prod.yml` 完了通知 | EventBridge + Lambda + 管理者通知ペイロード | **Gap**: AWS アカウント・EventBridge/Lambda 実環境はリポジトリ未接続 (`not-run`) |

## 2. 一次情報確認状況

- 参照 URL: `https://docs.aws.amazon.com/appstream2/latest/developerguide/use-image-assistant-cli.html` (`200 OK`, title: `Amazon WorkSpaces Applications`)
- 個別 CLI サブコマンド・オプションの詳細動作および S3/EventBridge/Lambda 実機実行は当環境では未実施のため **未確認** (`not-run`) とする。

## 3. Dry-Run パイプライン検証項目

1. `appVersion` / `installerUri` (`s3://` または `https://`) の形式検証
2. `sha256`（64桁 16進数）チェックサム検証
3. `targetFleets` の段階ロールアウト順序生成と管理者通知ペイロード生成（実 AWS API は呼び出さない）
4. DB マイグレーションは `0` 件
