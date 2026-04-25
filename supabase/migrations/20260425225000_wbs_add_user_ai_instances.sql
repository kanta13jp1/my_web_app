-- PS#4 S48: WBS instance拡張 — gemini / co-pilot / user 追加 (2026-04-25)
-- ユーザー手動タスク (user) + AI エージェント (gemini / co-pilot) の追加
-- 'all' は Win#132 part 16 (20260425203000) で廃止済み

-- ============================================================
-- 1. CHECK 制約更新 (instance + owner_instance)
-- ============================================================

ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_instance_check;
ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_instance_check
  CHECK (instance IN (
    'codex',
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule', 'gha',
    'gemini', 'co-pilot', 'user'
  ));

ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_owner_instance_check;
ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_owner_instance_check
  CHECK (owner_instance IN (
    'codex',
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule', 'gha',
    'gemini', 'co-pilot', 'user'
  ));

COMMENT ON COLUMN public.wbs_tasks.instance IS
  'Execution instance. Valid values: codex/vscode/win/ps1-ps6/web/mobile/schedule/gha/gemini/co-pilot/user. "user" = requires manual human action (signing, filing, physical presence).';

COMMENT ON COLUMN public.wbs_tasks.owner_instance IS
  'Primary owner instance. Valid values: codex/vscode/win/ps1-ps6/web/mobile/schedule/gha/gemini/co-pilot/user.';

-- ============================================================
-- 2. ユーザー手動タスクを instance='user' に再割当
--    対象: 法的手続き・物理的手続き・署名・届出が必要なタスク
-- ============================================================

UPDATE public.wbs_tasks
SET
  instance       = 'user',
  owner_instance = 'user',
  updated_at     = now()
WHERE
  -- 会社設立・法務登記
  title ILIKE '%会社設立%'
  OR title ILIKE '%登記%'
  OR title ILIKE '%定款%'
  -- 銀行・金融口座
  OR title ILIKE '%銀行口座%'
  OR title ILIKE '%口座開設%'
  -- 行政・税務届出
  OR title ILIKE '%税務署%'
  OR title ILIKE '%届出%'
  OR title ILIKE '%申告%'
  OR title ILIKE '%許認可%'
  -- 契約・署名
  OR title ILIKE '%契約書%'
  OR title ILIKE '%署名%'
  OR title ILIKE '%印鑑%'
  -- 資金調達 (実際の意思決定)
  OR title ILIKE '%出資%'
  OR title ILIKE '%融資%'
  OR title ILIKE '%投資家%'
  -- 採用・面接 (物理)
  OR title ILIKE '%採用面接%'
  OR title ILIKE '%内定%'
  -- 労務
  OR title ILIKE '%社会保険%'
  OR title ILIKE '%雇用保険%'
  OR title ILIKE '%労働保険%'
  -- 公的認証・資格
  OR title ILIKE '%公証%'
  OR title ILIKE '%認証%'
;

-- ============================================================
-- 3. 実績記録
-- ============================================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS instance拡張 — gemini/co-pilot/user 追加 (PS#4 S48)',
  'wbs_tasks CHECK制約拡張 (instance/owner_instance に gemini・co-pilot・user を追加) + ' ||
  'ユーザー手動タスク (登記/口座/届出/契約/労務系) を owner_instance=''user'' に自動再割当 + ' ||
  'Slack通知 workflow で毎朝9時にuser担当タスク一覧をプッシュ',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
