-- Win版#132 part 16: WBS instance='all' 廃止 + 'codex' 追加
--
-- 契機: ユーザー要請「WBS の instance='all' は進捗が見えないので廃止 / 各 instance
-- 個別タスク化 + codex を instance 種類に追加」
--
-- 既存: instance CHECK = ('vscode','win','ps1'..'ps6','web','mobile','schedule','gha','all')
-- 新:   instance CHECK = ('vscode','win','ps1'..'ps6','web','mobile','schedule','gha','codex')
--       ※ 'all' を削除 / 'codex' を追加
--
-- 既存 'all' タスクは category 別 default rule で再割当:
--   business-legal/finance/ops/ipo → win (経営事項)
--   business-product → win (バックエンド主)
--   business-marketing → ps2 (T-1 dispatch / SNS)
--   business-sales → ps5 (CS)
--   business-hr → win (採用判断)
--   その他カテゴリ未分類 → vscode (UI 主)
--
-- owner_instance は part 11 で既に 'all' 禁止済 (codex 既に許可値)。

-- ============================================================
-- 1. 既存 'all' タスクを category 別に再割当 (CHECK 制約変更前に必須)
-- ============================================================
UPDATE public.wbs_tasks
SET instance = CASE
  -- 事業化タスク (Win#132 part 11 seed)
  WHEN category = 'business-legal'      THEN 'win'
  WHEN category = 'business-finance'    THEN 'win'
  WHEN category = 'business-product'    THEN 'win'
  WHEN category = 'business-marketing'  THEN 'ps2'
  WHEN category = 'business-sales'      THEN 'ps5'
  WHEN category = 'business-hr'         THEN 'win'
  WHEN category = 'business-ops'        THEN 'win'
  WHEN category = 'business-ipo'        THEN 'win'
  -- 開発系既存タスク (UI/UX 系は VSCode へ / それ以外は Win)
  WHEN category LIKE '%UI%' OR category LIKE '%design%' OR category LIKE '%デザイン%' THEN 'vscode'
  WHEN category LIKE '%marketing%' OR category LIKE '%blog%' OR category LIKE '%SNS%' THEN 'ps2'
  WHEN category LIKE '%CS%' OR category LIKE '%support%'    THEN 'ps5'
  WHEN category LIKE '%horse%' OR category LIKE '%batch%'   THEN 'ps6'
  WHEN category LIKE '%AI大学%' OR category LIKE '%provider%' THEN 'ps3'
  WHEN category LIKE '%competitor%' OR category LIKE '%競合%' THEN 'ps4'
  -- default fallback (Win 経営担当 / すべて含めて IPO 責任)
  ELSE 'win'
END
WHERE instance = 'all';

-- 注: owner_instance は既に 'all' 不可 (Win#131 part 15 = 20260421030000) なので変更不要

-- ============================================================
-- 2. instance CHECK 制約: 'all' を削除 + 'codex' を追加
-- ============================================================
ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_instance_check;
ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_instance_check
  CHECK (instance IN (
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule',  -- Claude Code Schedule (cron で自動実行)
    'gha',       -- GitHub Actions Workflow
    'codex'      -- OpenAI Codex (frontend / SQL / GHA タスク)
    -- 'all' は廃止 (進捗 tracking 不可だったため / 2026-04-25 Win#132 part 16)
  ));

COMMENT ON COLUMN public.wbs_tasks.instance IS
  '担当 instance / agent。2026-04-25 以降 ''all'' は廃止 (各 instance 個別 task に分割 / 進捗 tracking 改善)。codex は OpenAI Codex 担当タスク用 (frontend Dart / SQL / GHA)。';

-- ============================================================
-- 3. 関連 EF も追記方針: schedule-hub:wbs.unblock_dependents の VALID_INSTANCES 設定は
--    schedule-hub/index.ts 側で更新済 (本 commit 同時)
-- ============================================================

-- ============================================================
-- 4. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS instance=all 廃止 + codex 追加',
  $md$Win版#132 part 16。ユーザー要請「instance=all は進捗 tracking 不可なので廃止 / 各 instance 個別タスク化 + codex を有効値に追加」。既存 'all' タスクを category 別 default rule で再割当: business-legal/finance/product/hr/ops/ipo → win, business-marketing → ps2, business-sales → ps5, UI 系 → vscode 等。CHECK 制約を更新 (codex 追加 / all 削除)。owner_instance は part 15 で既に all 禁止 + codex 許可済。schedule-hub の VALID_INSTANCES set も同期更新。$md$,
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
