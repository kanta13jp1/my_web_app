---
title: Ephemeral Instance User Data Persistence & Home Folder Evaluation
last_reviewed: 2026-11-26
review_cycle_days: 90
related_issue: 2799
---

# 非永続インスタンス ユーザーデータ永続化（ホームフォルダ連携）評価 (#2799)

## 1. 現行 `my_web_app` との Fit & Gap 分析

| 項目 | 現行スタック (`my_web_app`) | AppStream 2.0 ホームフォルダ構成 | Fit / Gap |
|---|---|---|---|
| **ファイル永続化基盤** | Supabase Storage (RLS ユーザー分離) | Amazon S3 バックエンド Home Folders | **Gap**: 現行は Web + Supabase Storage であり、AWS 仮想デスクトップ導入時のみ S3 Home Folders を利用 |
| **転送・クリップボード統制** | ブラウザ標準サンドボックス | スタックポリシー（Upload/Download/Clipboard 制限） | **Fit**: `scripts/home_folder_policy_check.py` でポリシー設定を事前検証可能 |
| **実環境動作** | `deploy-prod.yml` | AWS S3 / セッションスクリプト実機同期 | **未確認** (`not-run`: 当環境では実 AWS スタックを作成・検証していない) |

## 2. 一次情報参照

- `https://docs.aws.amazon.com/appstream2/latest/developerguide/home-folders.html` (`200 OK`: `Enable and Administer Home Folders for Your WorkSpaces Applications Users`)
- 個別 S3 同期レイテンシおよび実機セッション維持挙動は **未確認** (`not-run`)。

## 3. セキュリティポリシー検査基準

1. `homeFolderEnabled: true` かつ `encryptionEnabled: true`、`publicAccessBlocked: true` であること。
2. `syncPaths` にパストラバーサル（`..`）を含まないこと。
3. `strictSecurityMode: true` 時は `allowClipboardToLocal` および `allowDownload` が `false` であること。
4. DB マイグレーションは `0` 件。
