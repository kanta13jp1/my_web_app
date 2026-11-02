# Slack + Notion Workspace 手動セットアップ手順書

**策定**: 2026-04-24 (Win版#132 part 5)
**対象**: ユーザー本人 (kanta13jp1)
**所要時間**: Slack 15 分 + Notion 20 分 = 計 35 分
**前提**: `docs/DEV_PROCESS_MULTI_AI.md` §8-9 を読了していること

---

## 現状 (2026-04-24 08:00 JST 時点)

- ✅ `SLACK_WEBHOOK_URL` (default) — GitHub Secrets に設定済 (commit a30d3b50)
- ❓ `SLACK_WEBHOOK_QUOTA` — 未設定 (channel 別 routing 用)
- ❓ `SLACK_WEBHOOK_CI` — 未設定 (channel 別 routing 用)
- ❌ Notion 全て未設定

→ 本手順書では **残タスク** (Slack 2 ch + Notion 全体) を実施する。

---

## Part A. Slack 追加セットアップ (所要 10 分)

既に `SLACK_WEBHOOK_URL` (default) は設定済。追加で `#jibun-quota` / `#jibun-ci` 専用 webhook を取得する。

### A-1. Slack Workspace で 5 channel 作成 (未作成なら)

Slack app / Web 画面で以下 channel を作成 (Private / Public どちらでも):

| Channel | 用途 | 投稿元 |
|---------|------|--------|
| `#jibun-handoff` | **既存 default** — インスタンス間非同期 handoff | GHA / 手動 |
| `#jibun-quota` | quota 状態変化のみ | Supabase trigger (Win 実装予定) |
| `#jibun-ci` | GHA workflow 失敗通知 | workflow-failure-handler.yml |
| `#jibun-daily` | 毎朝 08:00 メトリクス digest | schedule-daily-digest EF |
| `#jibun-alerts` | 本番障害 P0/P1 | health-check EF |

作成方法: Slack 左サイドバー > Channels > `+` > "Create a new channel"

### A-2. Incoming Webhooks app 設定画面にアクセス

1. <https://api.slack.com/apps> を開く
2. 既存 app "自分株式会社 bot" (or 相当名) を選択
   - 無ければ "Create New App" > "From scratch" > Workspace 選択 > Create
3. 左メニュー **"Features > Incoming Webhooks"**
4. "Activate Incoming Webhooks" が **ON** になっていることを確認

### A-3. 追加 Webhook URL を 2 つ取得

現在の画面に既存 Webhook (default) があるはず。その下の **"Add New Webhook to Workspace"** ボタンから追加:

#### Webhook for QUOTA (`#jibun-quota`)

1. "Add New Webhook to Workspace" クリック
2. "Where should [app] post?" → **`#jibun-quota`** 選択
3. "Allow" クリック
4. 表示された Webhook URL をコピー

    ```text
    https://hooks.slack.com/services/T.../B.../xxxxxxxxxxxxxxxxxxxx
    ```

#### Webhook for CI (`#jibun-ci`)

同じ手順で `#jibun-ci` 向けも作成してコピー。

### A-4. 動作確認

ローカル Terminal で test post:

```bash
# QUOTA webhook テスト
curl -X POST "https://hooks.slack.com/services/.../B.../..." \
  -H "Content-Type: application/json" \
  -d '{"text":"✅ [test] SLACK_WEBHOOK_QUOTA 動作確認"}'

# CI webhook テスト
curl -X POST "https://hooks.slack.com/services/.../B.../..." \
  -H "Content-Type: application/json" \
  -d '{"text":"✅ [test] SLACK_WEBHOOK_CI 動作確認"}'
```

それぞれの Slack channel に `✅ [test] ...` が投稿されれば成功。

### A-5. GitHub Secrets 登録

```bash
# GitHub CLI 経由 (推奨)
gh secret set SLACK_WEBHOOK_QUOTA --body "https://hooks.slack.com/services/..."
gh secret set SLACK_WEBHOOK_CI    --body "https://hooks.slack.com/services/..."
```

または GitHub Web UI:

1. <https://github.com/kanta13jp1/my_web_app/settings/secrets/actions>
2. "New repository secret" × 2
   - Name: `SLACK_WEBHOOK_QUOTA` / Value: 上記 URL
   - Name: `SLACK_WEBHOOK_CI` / Value: 上記 URL

### A-6. Supabase Secrets 登録

```bash
# Supabase CLI 経由 (推奨)
supabase secrets set SLACK_WEBHOOK_QUOTA="https://hooks.slack.com/services/..."
supabase secrets set SLACK_WEBHOOK_CI="https://hooks.slack.com/services/..."
```

または Supabase Dashboard:

1. <https://supabase.com/dashboard/project/smmkxxavexumewbfaqpy/settings/functions>
2. "Edge Function Secrets" セクション
3. "Add new secret" × 2 (名前 + 値を入力)

### A-7. Slack Part 完了チェック

- [ ] `#jibun-quota` channel 作成
- [ ] `#jibun-ci` channel 作成
- [ ] Webhook URL (QUOTA) 取得
- [ ] Webhook URL (CI) 取得
- [ ] curl test 投稿成功 (2 channel)
- [ ] GitHub Secrets 登録 (2 つ)
- [ ] Supabase Secrets 登録 (2 つ)

---

## Part B. Notion Workspace セットアップ (所要 20 分)

### B-1. Notion Workspace 準備

既存 Notion account で OK (無ければ <https://www.notion.so/> で無料 sign up)。
Free plan で十分 (API は全 plan で使用可)。

### B-2. 階層構造を手動作成

Notion UI で以下の structure を作る:

```text
📁 自分株式会社 mirror   (top-level page)
  ├── 📄 ROADMAP          (empty page)
  ├── 🗂 WBS Tasks         (empty Database - Table view)
  ├── 🗂 Memory Index      (empty Database - Table view)
  └── 📄 Today's Digest    (empty page)
```

#### B-2-1. top-level page 作成

1. 左サイドバー下部 "+ Add a page"
2. Page タイトル: **`自分株式会社 mirror`**
3. アイコン: 📁 (任意)

#### B-2-2. 子 page / database 作成

top-level page 内で "/" コマンドで追加:

- `/page` → "ROADMAP"
- `/database table` → "WBS Tasks"
- `/database table` → "Memory Index"
- `/page` → "Today's Digest"

#### B-2-3. "WBS Tasks" database の properties 設定

新規 Database は default で "Name" (Title) + "Tags" (Multi-select) が付く。以下に変更:

| Property 名 | Type | 備考 |
|------------|------|------|
| `id` | **Title** (既存の Name を rename) | 主キー |
| `title` | Text | task タイトル |
| `instance` | Select | options: `vscode` / `win` / `ps1`-`ps6` / `web` / `mobile` / `all` |
| `status` | Select | options: `pending` / `in_progress` / `completed` / `blocked` |
| `progress` | Number | 0-100 |
| `deadline` | Date | end_date |
| `updated_at` | Date (Include time) | 最終更新 |

操作:

1. Database 右上 "Properties" メニュー
2. "+ New property" で追加 / 既存 property 編集
3. Select の options は手動追加 (後で API からも追加可)

#### B-2-4. "Memory Index" database の properties 設定

| Property 名 | Type | 備考 |
|------------|------|------|
| `filename` | **Title** | 例: `project_20260424_win132_part4.md` |
| `type` | Select | options: `feedback_success` / `feedback_correction` / `project` |
| `timestamp` | Date | YYYYMMDD |
| `description` | Rich text | 1 行サマリ |

### B-3. Notion Integration 作成

1. <https://www.notion.so/my-integrations> にアクセス
2. **"+ New integration"** クリック
3. 基本情報:
   - **Name**: `自分株式会社 Sync`
   - **Associated workspace**: 上記で作成した workspace
   - **Type**: **Internal** (Public は不要)
   - **Logo**: 任意
4. **"Submit"** クリック
5. 遷移先で **"Internal Integration Secret"** をコピー
   - 形式: `secret_xxxxxxxxxxxxxxxxxxxxxxxx...`
   - 絶対に公開しない (GitHub に commit 不可)

### B-4. Capabilities の確認 (最小権限)

Integration 設定画面の "Capabilities" tab:

- ✅ Read content
- ✅ Update content
- ✅ Insert content
- ❌ **No user information** (個人情報不要)
- Comment: 不要

→ "Save changes"

### B-5. Integration を page/database に接続

各 page/DB に integration 権限を明示的に与える必要がある:

1. Notion UI で **`自分株式会社 mirror`** page を開く
2. 右上 **"..."** メニュー
3. **"Connections"** > **"+ Add connections"**
4. **`自分株式会社 Sync`** を選択 → **"Confirm"**

子 page / DB は階層で権限が継承される。個別に確認する場合は各 page/DB でも同操作を繰り返す。

### B-6. Page ID / Database ID を URL から取得

各 page / database の URL から ID (32 文字の hash) を抽出:

```text
例: https://www.notion.so/workspace/WBS-Tasks-abc123def456ghi789jkl012mno345pq
                                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                              これが Database ID (32 文字)
```

hyphen 区切り形式でも OK (API は両方受け入れる):

```text
abc123de-f456-ghi7-89jk-l012mno345pq
```

取得する 4 つの ID:

| Secret 名 | 対象 |
|----------|------|
| `NOTION_ROADMAP_PAGE_ID` | ROADMAP page |
| `NOTION_WBS_DATABASE_ID` | WBS Tasks database |
| `NOTION_WBS_DATA_SOURCE_ID` | WBS Tasks data source (複数 data source 時は必須) |
| `NOTION_MEMORY_DATABASE_ID` | Memory Index database |
| `NOTION_MEMORY_DATA_SOURCE_ID` | Memory Index data source (複数 data source 時は必須) |
| `NOTION_DIGEST_PAGE_ID` | Today's Digest page |

### B-7. 動作確認

ローカル Terminal で API 疎通テスト:

```bash
TOKEN="secret_xxxxxxxxxxxxxxxxxx"
DB_ID="abc123def456ghi789..."  # WBS Database ID を指定

# 2025-09-03 API: database container から data source ID を取得
curl -sf "https://api.notion.com/v1/databases/$DB_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Notion-Version: 2025-09-03" | python3 -m json.tool

# 返却された data_sources[0].id を指定して schema を取得
DATA_SOURCE_ID="def456..."
curl -sf "https://api.notion.com/v1/data_sources/$DATA_SOURCE_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Notion-Version: 2025-09-03" | python3 -m json.tool | head -30
```

成功例:

```json
{
    "object": "data_source",
    "id": "abc123de-f456-...",
    "title": [{"plain_text": "WBS Tasks", ...}],
    "properties": {
        "id": {"type": "title", ...},
        "title": {"type": "rich_text", ...},
        "instance": {"type": "select", ...},
        ...
    }
}
```

`"object": "data_source"` + properties 一覧が返れば成功。database に複数の
data source がある場合は `NOTION_*_DATA_SOURCE_ID`、または一意な
`NOTION_*_DATA_SOURCE_NAME` を Supabase Secret に登録する。

### B-8. Secrets 登録

**GitHub**:

```bash
gh secret set NOTION_API_TOKEN            --body "secret_xxx..."
gh secret set NOTION_ROADMAP_PAGE_ID      --body "abc123..."
gh secret set NOTION_WBS_DATABASE_ID      --body "def456..."
gh secret set NOTION_WBS_DATA_SOURCE_ID   --body "def456..."
gh secret set NOTION_MEMORY_DATABASE_ID   --body "ghi789..."
gh secret set NOTION_MEMORY_DATA_SOURCE_ID --body "ghi789..."
gh secret set NOTION_DIGEST_PAGE_ID       --body "jkl012..."
```

**Supabase**:

```bash
supabase secrets set NOTION_API_TOKEN="secret_xxx..."
supabase secrets set NOTION_ROADMAP_PAGE_ID="abc123..."
supabase secrets set NOTION_WBS_DATABASE_ID="def456..."
supabase secrets set NOTION_WBS_DATA_SOURCE_ID="def456..."
supabase secrets set NOTION_MEMORY_DATABASE_ID="ghi789..."
supabase secrets set NOTION_MEMORY_DATA_SOURCE_ID="ghi789..."
supabase secrets set NOTION_DIGEST_PAGE_ID="jkl012..."
```

### B-9. Notion Part 完了チェック

- [ ] Notion workspace 内に 4 つの page/DB 作成
- [ ] WBS Tasks DB に 7 properties 設定
- [ ] Memory Index DB に 4 properties 設定
- [ ] Internal Integration 作成
- [ ] Integration を 4 つの page/DB に接続
- [ ] 4 つの ID 取得
- [ ] curl 疎通テスト成功
- [ ] GitHub Secrets 5 つ登録
- [ ] Supabase Secrets 5 つ登録

---

## Part C. セットアップ完了報告

両方完了したら以下を実行 (Win/PS version に handoff シグナル):

```bash
# 1. GitHub Issue を起票 (Win 版が拾う)
gh issue create \
  --title "[READY] Slack + Notion 手動セットアップ完了 → Win 版 S2-S4 + N2-N5 実装開始可" \
  --label "automation,ready-for-win" \
  --body "Slack 3 ch + Notion 5 secrets 登録完了。DEV_PROCESS_MULTI_AI §8-10 Backlog 実装可能。"

# 2. または Slack に直接通知
curl -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"text":"✅ Slack + Notion manual setup complete — Win 側 S2-S4 + N2-N5 実装開始可"}'
```

→ Win 版が次 session で以下を実装:

- **S2**: `core-hub:slack.notify` EF action
- **S3**: `ai_circuit_breaker` OPEN → Slack post Supabase trigger
- **S4**: Discord webhook secondary channel
- **N2-N4**: `schedule-hub:notion.sync_{wbs,roadmap,memory_index}` actions
- **N5**: GHA cron 1h 毎 Notion sync 起動

---

## Part D. トラブルシューティング

### D-1. Slack Webhook が 404 返す

- Webhook URL が revoke された / app が uninstall された可能性
- <https://api.slack.com/apps> で app 存在確認
- "Install App" を再実行

### D-2. Notion "unauthorized" エラー

- Integration が page/DB に接続されていない
- Notion UI で "..." > "Connections" を再確認
- Integration 自身の capability が足りない (Read/Update/Insert すべて ON か)

### D-3. Database ID が 32 文字じゃない

- URL 最後の "?v=..." より前まで取得
- hyphen 含む / 含まない どちらも API は受容する

### D-4. Slack channel に投稿されない (200 OK なのに)

- Webhook が別 channel 向けの URL になっている可能性
- <https://api.slack.com/apps> > Incoming Webhooks で各 URL の投稿先 channel を確認

### D-5. Notion API rate limit

- 3 req/sec 制限 (average)
- GHA cron 1h 毎なら問題なし
- batch 同期時は `sleep 0.4` を間に入れる

---

## 参考

- Slack API docs: <https://api.slack.com/messaging/webhooks>
- Notion API docs: <https://developers.notion.com/reference/intro>
- Backlog: `docs/DEV_PROCESS_MULTI_AI.md` §10 (S1-S4 / N1-N5)
- 運用 runbook: `docs/AI_FALLBACK_RUNBOOK.md` (PS#6 S26)

---

## 改訂履歴

- **2026-04-24 (Win版#132 part 5)**: 初版作成。ユーザー手動セットアップの具体的手順書として策定。
