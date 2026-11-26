---
title: Flutter Architecture and Supabase Data Model
last_reviewed: 2026-11-26
review_cycle_days: 90
owner: platform-engineering
related_issue: 2793
---

# Flutter アーキテクチャ & Supabase データモデル設計 (#2793)

## 1. システム全体構成

本リポジトリ（`my_web_app`）は **Flutter Web (CanvasKit) + Supabase (PostgreSQL / Edge Functions)** の 2 層構成を採用し、組織的スケール下でも一貫した保守性と型安全性を維持する。

```text
[Flutter Web Client]
  ├─ lib/pages/        ── 画面ルート・Scaffold・ナビゲーション
  ├─ lib/features/     ── 機能別クリーンモジュール (domain / data / application / presentation)
  └─ lib/services/     ── Edge Function 呼び出し・ローカルガード・状態サービス
         │ (Supabase Client / HTTPS JSON)
         ▼
[Supabase Edge Functions (Deno)]
  ├─ core-hub/         ── 認証・家計台帳・フィードバック等の基盤アクション
  ├─ app-hub/          ── AI 機能・企業/管理機能・テレメトリ集計アクション
  └─ _shared/          ── 共通ガードレール・ルーター・チェックポイント・品質ゲート
         │ (Row-Level Security / Service Role Admin)
         ▼
[Supabase PostgreSQL]
  ├─ hub_data          ── 機能別 JSONB メタデータストア（source + user_id + metadata）
  ├─ app_analytics     ── 構造化イベント・監視ログ・コスト/感情テレメトリ
  └─ user_preferences  ── ユーザー単位の設定・プロファイル
```

## 2. データモデル設計原則

1. **RLS によるテナント分離**: すべてのユーザーデータは `user_id` をキーに Row-Level Security で分離する。
2. **後方互換マイグレーション**: 既存カラムの削除・型変更・リネームは [`DUAL_WRITE_TRANSITION_STANDARD.md`](./DUAL_WRITE_TRANSITION_STANDARD.md) に従い、14 日間の Expand → Dual-Write → Contract を遵守する。
3. **Dart Doc & Living Docs CI**:
   - パブリックサービス・モデルは `///` Dart Doc コメントを付与し、`dart doc --output doc/api` による API リファレンス生成に対応する。
   - 本ドキュメントの `last_reviewed` は [`scripts/check_living_docs_staleness.py`](../scripts/check_living_docs_staleness.py) により定期検査され、90 日超過時は自動リマインド Issue ペイロードを生成する。
