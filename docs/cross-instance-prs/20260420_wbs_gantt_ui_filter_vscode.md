# VSCode 宛: Gantt UI 未完了フィルタ + キャッシュ確認

- **起票元**: PS版#2 S17 (2026-04-20)
- **優先度**: HIGH (ユーザー報告「WBS、ガントチャートがまったく更新されません」の Flutter 側原因調査)
- **起票理由**: Win版#131 parts 10-21 で backend (schema / EF / view / cron / seed) は完成済。残 gap は Flutter UI 側 2 点のみ。

## Context

ユーザー要望 (2026-04-20):

> WBS、ガントチャートがまったく更新されません。未完了のタスクだけでフィルターできる機能も追加したいです。

### DONE (Win版#131 parts 10-21)

- `wbs_tasks` schema: `recovery_plan` / `recovery_planned_at` / `rescheduled_count` / `estimated_hours` / `owner_instance` 列追加
- instance CHECK: 13 値 (`vscode`/`win`/`ps1-6`/`web`/`mobile`/`schedule`/`gha`/`all`)
- View: `wbs_delayed_tasks_view` (delay_days + recovery_status) / `wbs_milestone_risk_view` (critical_overdue / over_capacity / tight)
- Seed: Claude Schedule 10 件 + GHA 4 件 (instance='schedule'/'gha')
- ALL reassign: 競合比較→win / 21社モニタリング→ps4 / LP→vscode
- イナズマ線 UI: `lib/pages/project_gantt_page.dart:1557` + class `LightningLine:2676` 実装済
- recovery_plan 読込: line 100 / 遅延 + 未記入 → Red warning: line 118

## VSCode 着手タスク

### 1. 未完了フィルタ toggle UI 追加

- `grep show_incomplete` → 0 hit で未実装確認。
- `lib/pages/project_gantt_page.dart` にフィルタ toggle (`status != completed`) 追加。
- 推奨位置: AppBar actions 横の `Switch` or `FilterChip`。
- 状態管理: 既存 `setState` で ok (複雑 state 機械不要)。

### 2. Gantt データ反映経路の確認 (cache / fetch)

- ユーザー「まったく更新されません」報告 → backend は更新されているので原因は Flutter 側:
  a. Flutter Web の HTTP キャッシュ (CDN / service worker)
  b. `tools-hub:wbs.list_tasks` fetch tr失敗の silent 握りつぶし
  c. Firebase Hosting deploy の反映遅延
- 切り分け手順:
  1. 本番 <https://my-web-app-b67f4.web.app/project-gantt> 開いて Network tab で `tools-hub` 呼出確認
  2. response に `recovery_plan` / Schedule / GHA タスク含まれるか確認
  3. 含まれない場合 → query filter / 列 select 漏れ / キャッシュ
  4. 含まれる場合 → UI 表示ロジック (filter / sort / hide) バグ

### 3. planned_start_date / planned_end_date 列表示確認

- ユーザー要望: 「開始予定日、完了予定日の列も追加してください」。
- 現 schema は `start_date` / `end_date` が planned 扱い (actual は別定義無し)。
- UI 列として明示ラベル「開始予定 / 完了予定」化推奨 (backend 変更不要・ラベル変更のみ)。

## 関連

- Schema: `supabase/migrations/20260420090000_extend_wbs_10_instances.sql`
- Seed: `supabase/migrations/20260420140000_wbs_explode_all_seed_schedule_gha.sql`
- View: 同上 (`wbs_milestone_risk_view`)
- EF action: `supabase/functions/tools-hub/index.ts:690-897`
- Cron: `.github/workflows/wbs-staleness-audit.yml`

## SLA

- この cross-instance-pr は `docs/` 1 ファイル追加のみ。VSCode 本実装は 48h 以内着手推奨 (INSTANCE-ROLES Rule)。


---

## 🚨 PREREQ FIX (PS#6 S22 2026-04-20 commit 232b2783)

本 handoff 着手の前に **tools-hub の wbs.* dispatch bug が修復された** ことを確認:

- **Bug**: `supabase/functions/tools-hub/index.ts` line 335 で wbs.* 全 9 actions が horseracing switch 内に誤ネスト → `startsWith("horseracing.")` false で unreachable → 401 Unauthorized silent fail (2 週間潜伏)
- **Fix**: line 335 の条件を `|| action.startsWith("wbs.")` で拡張 (commit 232b2783 main)
- **確認 curl**:
  ```bash
  curl -X POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/tools-hub \
    -H "Authorization: Bearer <ANON_KEY>" -H "Content-Type: application/json" \
    -d "{\"action\":\"wbs.priority_for_instance\",\"instance\":\"ps6\"}"
  ```
  期待値: `{"success":true,"instance":"ps6","top_tasks":[...]}`

deploy-prod 反映まで最大 11 min × 並行数。反映確認後に本 handoff 作業着手可。

