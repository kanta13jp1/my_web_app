# Supabase Edge Functions 一覧 (2026-03-27 時点)

## UI から呼び出し済み ✅

| Function | 呼び出し元 | 用途 |
|----------|-----------|------|
| `ai-assistant` | `ai_assistant_menu.dart`, `ai_service.dart` | AIアシスタント (メモ編集時) |
| `ai-search` | `ai_status_page.dart` | AI検索 |
| `ai-suggest-tags` | `ai_status_page.dart` | AIタグ提案 |
| `daily-judgment` | `ai_secretary_page.dart` | デイリー判定 |
| `development-achievements` | `development_achievements_card.dart` | 開発実績 GET/ADD |
| `get-admin-users` | `admin_analytics_page.dart` | 管理者ユーザー一覧 |
| `get-competitor-features` | `growth_roadmap_progress_card.dart` | 競合19社機能比較 |
| `get-growth-roadmap-progress` | `growth_roadmap_progress_card.dart` | 進捗バーデータ |
| `get-home-dashboard` | `admin_analytics_page.dart` | ホーム統合データ |
| `get-support-tickets` | `admin_analytics_page.dart` | CSチケット一覧 |
| `growth-acquisition-report` | `growth_mission_service.dart` | 獲得チャネルレポート |
| `growth-acquisition-signal` | `growth_acquisition_service.dart` | 獲得シグナル記録 |
| `growth-command-center` | `growth_mission_service.dart` | 成長コマンドセンター |
| `growth-import-commit` | `import_service.dart` | インポート実行 |
| `growth-import-preview` | `import_service.dart` | インポートプレビュー |
| `growth-referral` | `growth_mission_service.dart` | リファラル |
| `growth-share-signal` | `growth_mission_service.dart` | シェアシグナル記録 |
| `growth-weekly-digest` | `growth_mission_service.dart` | 週次ダイジェスト |
| `notify-feature-request` | `admin_analytics_page.dart` | 機能リクエスト通知 |
| `post-x-update` | `admin_analytics_page.dart` | X投稿 |
| `reply-support-request` | `admin_analytics_page.dart` | CSチケット返信 |
| `schedule-daily-digest` | `admin_analytics_page.dart` | 日次ダイジェスト |
| `trigger-analysis` | `election_strategy_page.dart` | 分析トリガー |
| `get-public-memo-preview` | `public_memo_service.dart` | 公開メモプレビュー |
| `get-ogp` | `landing_page_adapter.dart` | OGP取得 |
| `growth-achievement-summary` | `cmo_page.dart` | 実績サマリー |

## Schedule タスクから呼び出し (UI 不要) 🤖

| Function | Schedule タスク | 用途 |
|----------|---------------|------|
| `health-check` | `infra-health-check` | インフラ監視 |
| `check-competitor-updates` | `competitor-monitoring` | 競合可用性チェック |
| `schedule-daily-digest` | `daily-report` | 日次メトリクス |
| `get-support-tickets` | `cs-check` | CS自動化 |
| `reply-support-request` | `cs-check` | CS返信自動化 |
| `post-x-update` | `daily-report` | X自動投稿 |

## UI からの導線なし ⚠️ (要対応)

| Function | 状況 | 推奨アクション |
|----------|------|--------------|
| `agent-runtime-cycle` | `agent_org_service.dart` で RPC 経由だが、直接 invoke なし | lib/ で呼び出し追加 (VSCode版担当) |
| `generate-daily-challenges` | `daily_challenge_service.dart` で RPC 使用 | RPC経由で動作中、追加不要 |
| `generate-quote-image` | 直接呼び出しなし | lib/ で名言画像生成UI追加 (VSCode版担当) |
| `share-quote` | 直接呼び出しなし | lib/ でシェア機能から呼び出し追加 (VSCode版担当) |
| `send-waitlist-notification` | 直接呼び出しなし (バックエンドトリガー) | Supabase DB Webhook から呼び出し、UI不要 |

## まとめ

- **合計**: 33 Edge Functions
- **UI から呼び出し済み**: 26 (79%)
- **Schedule から呼び出し**: 6 (一部UIと重複)
- **UI 導線なし・要対応**: 3 (`generate-quote-image`, `share-quote`, `agent-runtime-cycle`)
- **バックエンドのみ・UI不要**: 2 (`send-waitlist-notification`, `generate-daily-challenges`)
