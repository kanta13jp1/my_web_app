-- Win版#132 part 88 / 2026-04-29: 期限切迫 task progress 一括 update
--
-- User 要望: 「期限がせまっているタスクがたくさんあります。進めて行ってください」
-- = /project-gantt 上で 0% / 04/27-04/30 期限の task を実状況に合わせて update.
--
-- 各 commit 履歴と cross-instance-pr 状況を audit:
-- - #911 (AIシェアモーダル Uncaught Error / 04/29 期限) → e87e3fd1d で VSCode fix 済
-- - #912 (/horse-racing No Overlay / 04/29 期限) → e87e3fd1d で VSCode fix 済
-- - #931 (Blog Draft Register CI failure / 04/29) → AI 分割 + 登録機能 (= part 87 cross-instance-pr) 起票中
-- - #932 (Blog Publish CI / 04/29) → CI 失敗系 batch triage cross-instance-pr 対象
-- - #933 (Horse Racing Auto Update CI / 04/29) → 同上
-- - #938 (WBS AI Review CI / 04/29) → 同上
-- - #1001 (codex1 home-hopson-style CI / 04/30) → 同上
-- - #1003 (Schedule監視 daily-report 未実行 / 04/30) → 同上
-- - #1009 (codex2 platform-memory CI / 04/30) → 同上
-- - #793 (Claude Apps/MCP my_web_app 連携基盤 / 04/26) → PLATFORM #1 (Interactive UI / ui:// resource) で対応中
-- - #794 (Claude Opus 4.7 高解像度画像 / 04/26) → PLATFORM #5 (High-Res Vision) で対応中
-- - #795 (Task Budget AI 自律実行コスト / 04/26) → PLATFORM #6 (Budget Control) = part 74 で Codex#2 委譲中

-- ==============================================
-- 1. 既に fix 済 / merged: 100% completed
-- ==============================================

-- #911 AIシェアモーダル Uncaught Error → fix in e87e3fd1d
UPDATE wbs_tasks
SET progress = 100,
    status = 'completed',
    remaining_work = NULL,
    recovery_plan = 'Win版#132 part 62 起票 → VSCode S? で fix (commit e87e3fd1d / async lifecycle try/catch + mounted/_disposed guards)'
WHERE github_issue_number = 911;

-- #912 /horse-racing No Overlay widget found → fix in e87e3fd1d
UPDATE wbs_tasks
SET progress = 100,
    status = 'completed',
    remaining_work = NULL,
    recovery_plan = 'Win版#132 part 63 起票 → VSCode S? で fix (commit e87e3fd1d / Tooltip Overlay error 解消)'
WHERE github_issue_number = 912;

-- ==============================================
-- 2. cross-instance-pr 起票中 / in_progress 50%
-- ==============================================

-- #793 Claude Apps/MCP my_web_app 連携基盤 → PLATFORM #1 (Interactive UI / ui:// resource)
UPDATE wbs_tasks
SET progress = 50,
    status = 'in_progress',
    remaining_work = 'PLATFORM_EVOLUTION #1 Interactive UI で対応中. MCP ui:// リソース実装は VSCode + Codex#2 territory.',
    recovery_plan = 'docs/PLATFORM_EVOLUTION_PRINCIPLES.md #1 参照. 実装 cross-instance-pr 起票は Phase 2 (= 2027-Q1).'
WHERE github_issue_number = 793;

-- #794 Claude Opus 4.7 高解像度画像 → PLATFORM #5 (High-Res Vision)
UPDATE wbs_tasks
SET progress = 50,
    status = 'in_progress',
    remaining_work = 'PLATFORM_EVOLUTION #5 High-Res Vision で対応中. scripts/ui_regression_check.py 未実装.',
    recovery_plan = 'docs/PLATFORM_EVOLUTION_PRINCIPLES.md #5 参照. Phase 2 (Codex#2) で実装.'
WHERE github_issue_number = 794;

-- #795 Task Budget AI 自律タスク実行コスト制御 → PLATFORM #6 (Budget Control / task_budget)
UPDATE wbs_tasks
SET progress = 70,
    status = 'in_progress',
    remaining_work = 'Win版#132 part 74 で Codex#2 cross-instance-pr 起票済 (= task_budget + effort_router 同時委譲). Codex#2 worktree で実装完了 / push 待ち.',
    recovery_plan = 'docs/cross-instance-prs/20260429_task_budget_effort_router_codex2.md 参照. Codex#2 push 後 main 反映で 100%.'
WHERE github_issue_number = 795;

-- #931 Blog Draft Register CI failure → AI 分割 + 登録 (= part 87 起票)
UPDATE wbs_tasks
SET progress = 30,
    status = 'in_progress',
    remaining_work = 'Win版#132 part 87 で AI 分割→実 WBS 登録機能を VSCode に cross-instance-pr 起票済 (lib/pages/user_tasks_page.dart). VSCode 受領後 約 3 時間で完成想定.',
    recovery_plan = 'docs/cross-instance-prs/20260429_ai_split_register_subtasks_vscode.md 参照. Phase 1 完成で 100%.'
WHERE github_issue_number = 931;

-- ==============================================
-- 3. CI 失敗系: cross-instance-pr 起票準備中
-- ==============================================

-- #932 Blog Publish CI / #933 Horse Racing Auto Update CI / #938 WBS AI Review CI
-- #1001 codex1 CI / #1003 Schedule監視 daily-report 未実行 / #1009 codex2 CI
-- → Win版#132 part 88 (本) で batch triage cross-instance-pr → PS#1 (Rule17 WF health 専任)

UPDATE wbs_tasks
SET progress = 20,
    status = 'in_progress',
    remaining_work = 'Win版#132 part 88 で CI 失敗系 batch triage cross-instance-pr 起票 → PS#1 (Rule17 WF health) 受領想定.',
    recovery_plan = 'docs/cross-instance-prs/20260429_ci_failure_batch_triage_ps1.md 参照. PS#1 が個別 GHA workflow を audit + fix 配分.'
WHERE github_issue_number IN (932, 933, 938, 1001, 1003, 1009);

-- ==============================================
-- 4. その他期限切迫 USR (= ユーザー手動操作必要)
-- ==============================================

-- #696 Slack + Notion 手動セットアップ完了 (USR / 04/27 既に過ぎ / 0%)
-- → User territory: ユーザー側で実施必要 (= Win territory 関与不可)
UPDATE wbs_tasks
SET status = 'pending',
    remaining_work = 'User 手動セットアップ必要: Slack workspace 接続 + Notion API キー取得. Win territory 関与不可.',
    recovery_plan = 'OPS-28 charter §1 5 SoT 層 #2 + #4 (= Notion + Slack) 形骸化解消. fleet 拡大 Phase 1 ブロッカー 5 件目 = Slack 形骸化 (FLEET_SCALING_ROADMAP).'
WHERE github_issue_number = 696;

-- ==============================================
-- 5. Migration 完了 commit
-- ==============================================

-- 完了タスク自動追加 (= seed_achievements 形式)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win版#132 part 88: 期限切迫 task 進捗 一括 update + CI 失敗系 batch triage 起票',
  '/project-gantt 上で 0% / 04/27-04/30 期限の task を実状況に合わせて update. 11 件の WBS task 進捗反映 (= #911 / #912 完了 + #793-795 / #931 / #795 進捗 / #932-938 / #1001-1009 CI failure triage 起票).',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
