# cross-instance-pr: User Task Report UI 実装依頼

**起票**: Win版#132 part 19 (2026-04-25)
**FROM**: Win 版
**TO**: VSCode 版
**期限**: 2026-05-05 (1 週間)
**SLA**: severity = normal / 24h トリアージ / 48h 着手

---

## 背景

ユーザー要請「user タスクの実施完了/状況を報告できる UI をサイト上に追加」を受けて、Win 側でバックエンド (テーブル + 2 EF actions) を実装済。VSCode 側で Flutter UI 担当。

## Win 側実装済 (Phase 1)

### Migration: `20260426000000_wbs_user_task_reports.sql`
- `wbs_user_task_reports` テーブル
- columns: task_id (FK) / reporter / progress / status / report_text / blockers / next_action / metadata / created_at
- RLS: public read / service_role write

### EF actions: `tools-hub`

#### `wbs.user_task_report`
入力:
```json
{
  "action": "wbs.user_task_report",
  "task_id": "<uuid>",
  "progress": 50,                        // 任意 (0-100)
  "status": "in_progress",               // 任意 (pending/in_progress/completed/blocked)
  "report_text": "司法書士 3 社見積取得済 / A 社が最安",  // markdown OK / 4000 字
  "blockers": "登記費用が予算超過",       // 2000 字
  "next_action": "B 社に値下げ交渉",      // 1000 字
  "reporter": "user"                      // default 'user'
}
```

出力:
```json
{
  "success": true,
  "task_id": "...",
  "task_title": "...",
  "new_progress": 50,
  "new_status": "in_progress",
  "report_id": "<report uuid>",
  "reported_at": "..."
}
```

guard:
- task が存在しない → 404
- task.instance != 'user' → 403 (`reason: non_user_task`)

#### `wbs.export_user_tasks_md`
NotebookLM 用 markdown export (UI 不要 / GHA cron が呼ぶ)。

## VSCode 側実装依頼

### 1. ページ: `lib/pages/user_tasks_page.dart` (新規)

**Route**: `/user-tasks` (既存 `/project-gantt` の隣に追加)

**機能**:
- `instance='user'` の active task 一覧表示 (priority desc / end_date asc)
- 各 task カード:
  - title / category / priority icon / progress / deadline
  - 最新の report (3 件まで) を時系列で表示
  - **「進捗を報告する」ボタン** → モーダル / sheet 表示
- モーダル: form フィールド
  - progress (0-100 slider)
  - status (dropdown: pending/in_progress/completed/blocked)
  - report_text (TextField multiline / markdown hint)
  - blockers (TextField multiline)
  - next_action (TextField multiline)
  - 「報告する」ボタン → `core-hub`/`tools-hub` 経由で `wbs.user_task_report` 呼出
- 報告成功 → snackbar `✅ 報告を記録しました` + 一覧 refresh

### 2. データ取得 (Supabase REST or EF action)

**方針 A**: Supabase REST 直で `wbs_tasks` + `wbs_user_task_reports` を fetch (推奨 / シンプル)
```dart
final tasks = await Supabase.instance.client
  .from('wbs_tasks')
  .select('id, title, category, status, progress, end_date, priority')
  .eq('instance', 'user')
  .inFilter('status', ['pending', 'in_progress', 'blocked'])
  .order('priority', ascending: false)
  .order('end_date', ascending: true);

final reports = await Supabase.instance.client
  .from('wbs_user_task_reports')
  .select('task_id, progress, status, report_text, blockers, next_action, created_at')
  .inFilter('task_id', taskIds)
  .order('created_at', ascending: false);
```

**方針 B**: 新 EF action `wbs.list_user_tasks_with_reports` を Win 側で追加 (柔軟だが overkill)

→ **方針 A 推奨** (RLS で public read 設定済 / anon key で読める)

### 3. report 投稿 (`wbs.user_task_report`)

```dart
final resp = await Supabase.instance.client.functions.invoke(
  'tools-hub',
  body: {
    'action': 'wbs.user_task_report',
    'task_id': task.id,
    'progress': progressValue,
    'status': statusValue,
    'report_text': reportText,
    'blockers': blockers,
    'next_action': nextAction,
  },
);
```

**注意**: tools-hub は **要 auth** (anonymous-allowed actions に未追加)。
ログインユーザーのみが報告できる前提で OK。

### 4. ナビゲーション
- `MainScaffold` のサイドバー or AppBar に「ユーザータスク」リンク追加
- もしくは `/project-gantt` ページから "📋 user タスク報告" ボタンで遷移

### 5. デザイン
- DESIGN.md トークン準拠
- priority icon: 🔴 high / 🟡 medium / 🟢 low
- status icon: ✅ completed / 🔧 in_progress / 🚧 blocked / ⏳ pending
- markdown rendering: `flutter_markdown` 使用 (既に依存にあれば)

## 動作確認

1. Notion/Slack 設定タスク等が `instance='user'` で表示される
2. 「進捗を報告する」→ form 入力 → 投稿 → 一覧の latest report に反映
3. progress=100 で auto-completed
4. 履歴 (時系列) が task カード内に表示

## 関連 commit

- Win 側 Phase 1: TBD (本 cross-instance-pr 起票時の commit)
- migration: `supabase/migrations/20260426000000_wbs_user_task_reports.sql`
- EF actions: `supabase/functions/tools-hub/index.ts` の `wbs.user_task_report` + `wbs.export_user_tasks_md`

## Philosophy 9/9 ✅

- 原則 1 (CEO 感): user 自身が進捗 self-report = CEO 視点維持
- 原則 5 (商品=ユーザー価値): 「やったよ」を 1 click で記録
- 原則 8 (KPI=昨日の自分): report history で時系列 visibility

## AI-DEV 7/7 ✅
- Auth ✅ (Supabase auth) / Deny-by-default ✅ (instance='user' guard) /
- trace_id ✅ (report id + created_at) / Cost CB ✅ (DB row のみ) /
- Team memory ✅ (wbs_user_task_reports = NotebookLM source) /
- Retry ✅ (失敗で再投稿可) / Quality gate ✅ (progress/status バリデーション)
