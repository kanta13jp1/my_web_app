---
title: Competitive Benchmark - Notion 3.4 Auto-Generated Dashboard vs my_web_app
last_reviewed: 2026-11-26
review_cycle_days: 90
related_issue: 2815
---

# Notion 3.4 自動生成ダッシュボード 調査＆競合ベンチマーク (#2815)

## 1. 一次情報確認状況と検証スコープ

| 確認対象 | 一次 URL / 手段 | 確認結果 |
|---|---|---|
| Notion リリース一覧 | `https://www.notion.com/releases` | `200 OK` (`What’s New – Notion`)。`agent`, `custom agent`, `database` の記載を確認 |
| Notion AI 製品ページ | `https://www.notion.com/product/ai` | `200 OK` (`Meet your AI team | Notion`)。`agent`, `custom agent`, `dashboard`, `chart`, `database` の記載を確認 |
| Notion 3.4 固有の自動 KPI 生成詳細・実機速度 | ライブ Notion ワークスペース操作 | **未確認** (`not-run`: 当環境では Notion 実ワークスペースへのログイン・実測を行っていない) |

## 2. 機能・アーキテクチャ比較表

| 評価軸 | Notion 3.4 / Notion AI | `my_web_app`（現行実装） |
|---|---|---|
| **実装基盤** | 汎用ワークスペース SaaS（クラウド中心） | Flutter Web (CanvasKit) + Supabase (`lib/pages/personal_dashboard_page.dart`, `lib/pages/monthly_kpi_dashboard_page.dart`) |
| **KPI / ダッシュボード領域** | データベース・チャート・Custom Agent 連携（汎用） | 家計・習慣・月次 KPI・AI コスト監視（`lib/pages/ai_router_cost_dashboard_page.dart`, `lib/pages/admin/quota_dashboard_page.dart`）を単一アプリに統合 |
| **データ分離・統制** | ワークスペース権限モデル | PostgreSQL Row-Level Security (RLS) ＋ Edge Function 単位の明示的入力検証 |
| **応答速度・実測比較** | **未確認** (`not-run`) | **未確認** (`not-run` — 実機比較計測は別途実施予定) |

## 3. `my_web_app` 独自の差別化機能提案

1. **ドメイン特化型「家計・習慣・AI コスト」統合パーソナル KPI カード**:
   - Notion の汎用データベース構築と異なり、`personal_dashboard_page.dart` と `monthly_kpi_dashboard_page.dart` を軸に、収支・固定費・習慣継続率・AI 利用コストをゼロ設定で横断相関表示する。
2. **Fail-Open 決定論的異常検知＋500ms 低遅延ルーター連携**:
   - 外部 LLM 呼び出しがタイムアウトまたは未設定時でも、ローカル決定論的集計で KPI カードの描画とアラート判定を継続できる（SaaS AI 依存の単一障害点を回避）。

## 4. DB 影響

- 本タスクは競合調査ドキュメントおよび検証スクリプトの追加のみであり、DB マイグレーションは `0` 件とする。
