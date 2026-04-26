# User 依頼: Slack + Notion 連携の手動セットアップ

**from**: Win版#132 part 29 (2026-04-26)
**to**: User (CEO / 自分株式会社)
**priority**: high (Win S2-S4 + N2-N5 ブロック解除のため)
**deadline**: 2026-04-30 (Win版#132 part 30 で着手するため)

## 背景

Master Brain (NotebookLM `ea6cff25`) 提案 #3「Slack + Notion 連携タスク (Win S2-S4 + N2-N5) の DB・設計準備」のため、user 側の **手動セットアップ** が必要。これが完了次第、Win版が DB schema + ai-hub action + Flutter UI を実装する。

## User 手動タスク (3 件)

### 1. Slack Workspace 作成 + App 登録 (15 分)

```
1. https://slack.com/create で workspace 作成 (「自分株式会社」など)
2. https://api.slack.com/apps → Create New App → From scratch
3. App Name: 「自分株式会社 Bot」
4. Bot Token Scopes: chat:write, channels:read, channels:history, users:read
5. Install App to Workspace → Bot User OAuth Token (xoxb-...) を取得
6. Bot Token を user-secrets vault (Bitwarden / 1Password 等) に保管
7. user-secrets の path を MEMORY.md に記録
   例: bitwarden://item/jibun-slack-bot-token
```

完了後 → user-secrets vault path を Win版へ slack message OR 手動でレポジトリの secrets 登録

### 2. Notion API token 発行 (10 分)

```
1. https://www.notion.so/my-integrations → New integration
2. Name: 「自分株式会社 Sync」
3. Capabilities: Read content, Update content, Insert content, Read comments
4. Submit → Internal Integration Token (secret_...) を取得
5. 連携対象の Notion page で「Add connections」→ 上記 integration を追加
6. Notion token + 連携 page ID を user-secrets vault に保管
```

### 3. Supabase Edge Function Secrets 登録 (5 分)

```
supabase secrets set SLACK_BOT_TOKEN=xoxb-... --project-ref smmkxxavexumewbfaqpy
supabase secrets set NOTION_API_TOKEN=secret_... --project-ref smmkxxavexumewbfaqpy
supabase secrets set NOTION_ROOT_PAGE_ID=<page-uuid> --project-ref smmkxxavexumewbfaqpy
```

OR: Supabase Dashboard → Edge Functions → Secrets タブから GUI で登録

## 完了通知方法

3 件すべて完了したら以下のいずれか:
- GitHub Issue 「Slack + Notion 手動セットアップ完了」を kanta13jp1/my_web_app に作成
- WBS task `714ee4a4-13c8-4161-9b78-de468660c3cf` の `user_report_status` を `completed` に更新 (project-gantt UI から)

## Win版 着手予定 (完了通知受領後)

| Task ID | タイトル | 担当 | 予想工数 |
|---------|---------|------|---------|
| Win S2 | Slack 通知 EF 実装 (`ai-hub:slack.send`) | Win版 | 1 session |
| Win S3 | Slack incoming webhook 受信 EF | Win版 | 1 session |
| Win S4 | Slack message → AI 要約 → 自分株式会社 home dashboard 表示 | Win版 + VSCode版 | 2 session |
| N2 | Notion page sync (read) → ai_university_content にミラー | Win版 | 1 session |
| N3 | Notion page sync (write) ← 自分株式会社 note 機能から | Win版 | 1 session |
| N4 | Notion database CRUD wrapper EF (`ai-hub:notion.crud`) | Win版 | 1 session |
| N5 | Notion + Slack 横断検索 (Master Brain RAG) | Win版 + VSCode版 | 2 session |

合計 約 1 週間で完了見込み。

## Philosophy Alignment

- 1 (CEO 感): User が token 管理権限を保持 ✅
- 5 (商品=価値): Slack/Notion 横断統合は note + memo 機能の中核 ✅
- 6 (資本=時間): 手動セットアップ 30 分 → 自動化機能数十時間分の価値 ✅
- 9 (IPO): エンタープライズ統合機能は B2B 営業材料 ✅

## 参考

- Master Brain 提案詳細: `memory/project_20260426_win132_part26.md`
- WBS user task: ID `714ee4a4-13c8-4161-9b78-de468660c3cf` "Slack + Notion 手動セットアップ完了"
- Anthropic Claude Apps が同分野競合 (`youtu.be/Zclp_zK9cYM` 参照)
