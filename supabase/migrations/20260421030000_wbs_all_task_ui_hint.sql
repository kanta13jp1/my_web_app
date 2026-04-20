-- WBS instance='all' タスク UI hint + owner_instance 必須化
-- Win版#131 part 15 / T4-Win (2026-04-21)
--
-- 参照: docs/cross-instance-prs/20260420_wbs_gantt_overhaul_phase2.md (T4)
--      docs/cross-instance-prs/20260421_wbs_all_tasks_split_design_win.md
--
-- ユーザー決裁 (2026-04-20 夜 by PS#4 S30):
--   T4 = (A) shared keep + UI warning — instance='all' 3 件 (ユーザー数 50/500/5000)
--        は共同責任として残置。Gantt UI 側で warning badge 追加 (VSCode版担当)。
--        複製はしない。
--
-- このマイグレーションで:
--   1. owner_instance を backfill (NULL を instance で埋める / 'all' は 'vscode' に)
--   2. owner_instance NOT NULL 制約追加
--   3. owner_instance に CHECK 制約 ('all' 不可: 'all' は primary owner を指定必須)
--   4. metadata COMMENT で ALL タスク運用方針を明文化

-- ============================================================
-- 1. owner_instance backfill
-- ============================================================
-- 1-a. NULL かつ instance != 'all' → instance をそのまま owner に
UPDATE wbs_tasks
SET owner_instance = instance
WHERE owner_instance IS NULL
  AND instance != 'all';

-- 1-b. NULL かつ instance = 'all' → primary owner = vscode (UI 統括)
UPDATE wbs_tasks
SET owner_instance = 'vscode'
WHERE owner_instance IS NULL
  AND instance = 'all';

-- 1-c. owner_instance = 'all' (part 13 で誤って 'all' が入ったケース保険) → vscode に集約
UPDATE wbs_tasks
SET owner_instance = 'vscode'
WHERE owner_instance = 'all';

-- ============================================================
-- 2. NOT NULL 制約
-- ============================================================
ALTER TABLE wbs_tasks
  ALTER COLUMN owner_instance SET NOT NULL;

-- ============================================================
-- 3. CHECK 制約 (owner_instance は 10 instance のみ / 'all' 禁止)
-- ============================================================
ALTER TABLE wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_owner_instance_check;
ALTER TABLE wbs_tasks ADD CONSTRAINT wbs_tasks_owner_instance_check
  CHECK (owner_instance IN (
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule', 'gha'
  ));

-- ============================================================
-- 4. metadata COMMENT 更新
-- ============================================================
COMMENT ON COLUMN wbs_tasks.instance IS
  '担当 instance (vscode/win/ps1-6/web/mobile/schedule/gha/all)。''all'' は全 instance 共同責任 goal (例: ユーザー数達成) のみ明示指定可。T4-Win (part 15): ''all'' タスクも owner_instance で primary owner 必須';

COMMENT ON COLUMN wbs_tasks.owner_instance IS
  '主担当 instance (リカバリー責任の明示用)。NOT NULL + ''all'' 禁止。instance=''all'' の共同責任タスクでも primary owner は必ず 1 instance に指定 (T4-Win part 15)';

-- ============================================================
-- 5. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS part 15: owner_instance 必須化 + ALL タスク運用方針明文化',
  $md$owner_instance を NOT NULL + ''all'' 禁止 CHECK 追加。instance=''all'' の共同責任タスク (ユーザー数 50/500/5000) も primary owner (= vscode) が必ず存在する構造に。UI 側の warning badge 表示 (VSCode版 T9-VSCode) と組で defense-in-depth。T4 = (A) shared keep + UI warning 決裁済。Win版#131 part 15 / T4-Win。$md$,
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
