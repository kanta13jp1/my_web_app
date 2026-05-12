# Supabase Edge Function 一覧

> Win版#132 part 133 (2026-05-05): 旧 CLAUDE.md L427-447 を移行 (= Karpathy 80 行 KPI 達成).
> 主要 EF のみ. 全件は `supabase/functions/` ディレクトリ参照.

## 主要 hub EF (= 多 action 統合)

| Function | 用途 |
| --- | --- |
| `tools-hub` | 個人生産性ツール統合 (= WBS / Issue / digest / agent_tool_policy 等) |
| `schedule-hub` (`digest.run`) | Schedule 用日次メトリクス API + blog auto_publish + blog.recent_posted (= part 124) + blog.backfill_from_apis |
| `growth-hub` | グロース指標 / share track / command analyze (= part 112 EF 移行) |
| `admin-hub` | 競合可用性チェック (`competitor.check`) ほか管理者向け統合 |
| `ai-hub` | AI 機能統合 (= ai-assistant / daily-judgment / ai-writing-assistant / customer-feedback) |
| `enterprise-hub` | A/B テスト / アクセス制御 / その他企業機能統合 |
| `memory-search-hub` | BM25 + vector search (= 4 actions / part 115 PS#5 実装) |

## サポート系 EF

| Function | 用途 |
| --- | --- |
| `get-support-tickets` | 未返信チケット + FAQ 一覧 (Schedule 用) |
| `reply-support-request` | チケット返信・エスカレーション |
| `notify-feature-request` | 機能リクエスト更新通知メール |
| `health-check` | インフラヘルスチェック |

## ホーム / dashboard 系

| Function | 用途 |
| --- | --- |
| `get-home-dashboard` | ホーム画面統合データ |
| `growth-weekly-digest` | 週次グロース指標 |
| `development-achievements` | 開発実績一覧 |
| `get-admin-users` | 管理者用ユーザー一覧 |
| `get-growth-roadmap-progress` | 進捗バーデータ (1900+ 競合 + 短中長期) |
| `get-competitor-features` | 競合機能比較データ |

## SNS / 配信系

| Function | 用途 |
| --- | --- |
| `post-x-update` | X (Twitter) 自動投稿 (`@kanta13jp1`) |

## 設計原則

- **EF-FIRST** (inject-rules.txt rule): 複雑ロジックは Flutter widget ではなく EF に置く
- **EF-CAP-50**: deploy-prod の EF 数は 50 本以下に維持. 超過時は hub 統合優先
- **deny-by-default** (AI_DEV_PRINCIPLES.md #2): EF 新 action は明示許可リストでホワイトリスト管理
- **trace_id + 5 秒超検出** (AI_DEV_PRINCIPLES.md #3): 各 step に trace_id

## 関連

- [`docs/DIRECTORY_STRUCTURE.md`](DIRECTORY_STRUCTURE.md) — リポジトリ全体構成
- [`docs/AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) — EF 設計 7 原則
- [`docs/SCHEDULE_TASKS.md`](SCHEDULE_TASKS.md) — EF を呼ぶ cron
- [`CLAUDE.md`](../CLAUDE.md) — pointer hub
