-- Win版#132 part 18: WBS instance 拡張 — gemini / copilot / user 追加
--
-- 契機: ユーザー要請「gemini, co-pilot, user を instance 種類に追加 / user タスクは
-- ユーザー手動操作タスク / 各セッションで user タスクをユーザーに通知 + Slack 通知」
--
-- 既存 (Win#132 part 16 / PS#6 並行): codex / vscode / win / ps1..ps6 / web / mobile / schedule / gha (12)
-- 新規追加 3:
--   - gemini   = Gemini Code Assist 担当タスク (大規模 refactor / 長文 code 系)
--   - copilot  = GitHub Copilot 担当タスク (inline 補完 / Chat / 短い修正)
--   - user     = ユーザー手動操作タスク (Notion 設定 / Slack Webhook 設定 / IPO 決裁等)
--
-- 合計 15 instance に拡張。

-- ============================================================
-- 0. データ正規化: 'co-pilot' (hyphen / PS#4 S48 = 225000) → 'copilot' (canonical)
--    Win#132 part 21 hotfix (2026-04-25): 225000 で 'co-pilot' が CHECK に追加された
--    場合に rows が混入しうる → 230000 では canonical 'copilot' に統一する。
-- ============================================================
UPDATE public.wbs_tasks
SET instance = 'copilot'
WHERE instance = 'co-pilot';

UPDATE public.wbs_tasks
SET owner_instance = 'copilot'
WHERE owner_instance = 'co-pilot';

-- ============================================================
-- 1. instance CHECK 制約 拡張
-- ============================================================
ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_instance_check;
ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_instance_check
  CHECK (instance IN (
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule',  -- Claude Code Schedule (cron 自動実行)
    'gha',       -- GitHub Actions Workflow
    'codex',     -- OpenAI Codex (frontend Dart / SQL / GHA)
    'gemini',    -- Gemini Code Assist (大規模 refactor / 長文)
    'copilot',   -- GitHub Copilot (inline 補完 / Chat) — canonical
    'co-pilot',  -- 225000 互換 alias (defense-in-depth / 230000 で copilot に統一済)
    'user'       -- ユーザー手動操作タスク (Notion 設定 / Slack Webhook / IPO 決裁等)
    -- 'all' は part 16 で廃止 (進捗 tracking 不可)
  ));

-- owner_instance も同期 (codex は part 15 で追加済 / gemini/copilot/user 追加)
ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_owner_instance_check;
ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_owner_instance_check
  CHECK (owner_instance IN (
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule', 'gha',
    'codex', 'gemini', 'copilot', 'co-pilot', 'user'
  ));

COMMENT ON COLUMN public.wbs_tasks.instance IS
  '担当 instance / agent。15 種類: vscode/win/ps1..ps6/web/mobile/schedule/gha/codex/gemini/copilot/user。
  user = ユーザー手動操作タスク (Notion DB option 編集 / Slack Webhook 設定 / 法人登記等)。
  各 session で wbs.notify_user_tasks 経由で Slack #jibun-handoff に通知。
  ''all'' は 2026-04-25 part 16 で廃止。';

-- ============================================================
-- 2. 既存「ユーザー手動」タスクを instance='user' に再割当
-- ============================================================
-- Slack/Notion セットアップ手順書記載の手動タスクを user 担当化
UPDATE public.wbs_tasks AS task
SET instance = 'user',
    owner_instance = 'user'
WHERE (
  -- Notion / Slack manual setup 系
  task.title ILIKE '%Notion%手動%' OR
  task.title ILIKE '%Slack%Webhook%設定%' OR
  task.title ILIKE '%Notion DB%' OR
  task.title ILIKE '%Notion Integration%' OR
  -- 法人登記 / 司法書士契約 (法人手続き)
  task.title ILIKE '%株式会社設立登記%' OR
  task.title ILIKE '%司法書士%契約%' OR
  task.title ILIKE '%商標出願%' OR
  -- 銀行口座 / 会計ソフト導入
  task.title ILIKE '%法人銀行口座%' OR
  task.title ILIKE '%会計ソフト導入%' OR
  -- IPO 関連の決裁系
  task.title ILIKE '%監査法人選定%' OR
  task.title ILIKE '%主幹事証券%' OR
  task.title ILIKE '%上場審査対応%'
)
  AND task.status != 'completed'
  AND NOT EXISTS (
    SELECT 1
    FROM public.wbs_tasks existing
    WHERE existing.title = task.title
      AND existing.instance = 'user'
      AND existing.id <> task.id
  );

-- ============================================================
-- 3. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS instance 拡張: gemini / copilot / user 追加',
  $md$Win版#132 part 18。ユーザー要請を受けて instance 種類を 12 → 15 に拡張。gemini (Gemini Code Assist 大規模 refactor) + copilot (GitHub Copilot inline 補完) + user (ユーザー手動操作タスク Notion 設定 / Slack Webhook / 法人登記 / 監査法人選定等) を追加。owner_instance 制約も同期。既存「ユーザー手動」タスク (Notion / Slack / 法人登記 / IPO 決裁系) を instance='user' に再割当。後続: tools-hub:wbs.notify_user_tasks action (本 commit 同時) + GHA daily cron で Slack #jibun-handoff 通知。$md$,
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
