-- WBS 拡張 part 13: ALL タスク explode + Schedule/GHA instance + マイルストーン risk 列
-- Win版#131 part 13 (2026-04-20)
--
-- ユーザー要望:
--   1. 'all' 担当だと「誰が更新すべきか」不明 → 共有タスクは instance 個別に explode
--   2. Claude Schedule タスク (daily-report 等) を WBS に反映
--   3. GHA workflow タスク (deploy-prod 等) を WBS に反映
--   4. マイルストーン超過警告 (estimated_hours / available_hours で risk 算出)

-- ============================================================
-- 1. instance CHECK 拡張: 'schedule' (Claude Schedule) + 'gha' (GitHub Actions)
-- ============================================================
ALTER TABLE wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_instance_check;
ALTER TABLE wbs_tasks ADD CONSTRAINT wbs_tasks_instance_check
  CHECK (instance IN (
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule',  -- Claude Code Schedule (cron で自動実行)
    'gha',       -- GitHub Actions Workflow
    'all'        -- 全 instance 共有 (UI で警告表示)
  ));

-- ============================================================
-- 2. estimated_hours 列追加 (マイルストーン risk 算出用)
-- ============================================================
ALTER TABLE wbs_tasks
  ADD COLUMN IF NOT EXISTS estimated_hours numeric(6,1) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS owner_instance text;

COMMENT ON COLUMN wbs_tasks.estimated_hours IS '完了までの見積工数 (h)。マイルストーン risk 算出に使用';
COMMENT ON COLUMN wbs_tasks.owner_instance IS '主担当 instance (instance=all のときの primary owner)。リカバリー責任の明示用';

-- ============================================================
-- 3. ALL タスクを再分類
-- ============================================================
-- 既存の 'all' タスク (7件) のうちカテゴリ明確なものは個別 instance に reassign:

UPDATE wbs_tasks SET instance = 'win',  owner_instance = 'win'
  WHERE instance = 'all' AND title LIKE '%競合比較ページ最新化%';

UPDATE wbs_tasks SET instance = 'ps4',  owner_instance = 'ps4'
  WHERE instance = 'all' AND title LIKE '%競合21社モニタリング%';

UPDATE wbs_tasks SET instance = 'vscode', owner_instance = 'vscode'
  WHERE instance = 'all' AND (title LIKE '%LP最適化%' OR title LIKE '%SEO改善%');

-- ユーザー数達成 (50/500/5000) は全 instance 共同責任 → owner_instance を vscode (主担当)
-- に明示 + UI で「全インスタンス共有」warning chip 表示するため instance='all' のまま残す
UPDATE wbs_tasks SET owner_instance = 'vscode'
  WHERE instance = 'all' AND title LIKE '%ユーザー数%';

-- ============================================================
-- 4. Claude Code Schedule タスクを seed (instance='schedule')
-- ============================================================
INSERT INTO wbs_tasks (
  category, category_icon, category_order, title, description,
  instance, owner_instance, status, progress, start_date, end_date,
  milestone_code, priority, estimated_hours
) VALUES
  ('Claude Schedule', '⏰', 8, 'daily-report (毎朝 09:00 JST)',
   '前日の開発実績・KPI 集計を Slack/Discord に通知',
   'schedule', 'ps1', 'in_progress', 100, '2026-04-01', '2026-12-31', 'alpha', 'medium', 0),
  ('Claude Schedule', '⏰', 8, 'cs-check (毎時)',
   'カスタマーサポート未返信チケット自動返信 + エスカレーション',
   'schedule', 'ps5', 'in_progress', 100, '2026-04-01', '2026-12-31', 'alpha', 'high', 0),
  ('Claude Schedule', '⏰', 8, 'github-issue-fix (毎日 10:00 JST)',
   'GitHub Issue 自動 triage + bug 修正 PR 作成',
   'schedule', 'ps5', 'in_progress', 90, '2026-04-01', '2026-12-31', 'alpha', 'high', 0),
  ('Claude Schedule', '⏰', 8, 'weekly-sns-draft (毎週月曜 09:00 JST)',
   '週次 X 投稿ドラフト + Zenn 記事ネタ生成',
   'schedule', 'ps2', 'in_progress', 80, '2026-04-01', '2026-12-31', 'alpha', 'medium', 0),
  ('Claude Schedule', '⏰', 8, 'pr-auto-review (3 時間ごと)',
   'open PR の Claude による自動コードレビュー',
   'schedule', 'ps1', 'in_progress', 100, '2026-04-01', '2026-12-31', 'alpha', 'high', 0),
  ('Claude Schedule', '⏰', 8, 'competitor-monitoring (毎日 07:00 JST)',
   '競合 21 社の Web サイト可用性 + 機能リリース監視',
   'schedule', 'ps4', 'in_progress', 100, '2026-04-01', '2026-12-31', 'alpha', 'high', 0),
  ('Claude Schedule', '⏰', 8, 'infra-health-check (毎時 30 分)',
   'health-check EF + Supabase + Firebase Hosting 監視',
   'schedule', 'ps1', 'in_progress', 100, '2026-04-01', '2026-12-31', 'alpha', 'high', 0),
  ('Claude Schedule', '⏰', 8, 'dependency-audit (毎週月曜 08:00 JST)',
   '脆弱性チェック + 依存関係 update PR',
   'schedule', 'ps1', 'in_progress', 100, '2026-04-01', '2026-12-31', 'alpha', 'medium', 0),
  ('Claude Schedule', '⏰', 8, 'blog-draft (毎日 08:00 JST)',
   'T-1 ブログドラフト生成 (PS#2 が dispatch)',
   'schedule', 'ps2', 'in_progress', 100, '2026-04-01', '2026-12-31', 'alpha', 'high', 0),
  ('Claude Schedule', '⏰', 8, 'ai-university-update (2 時間ごと)',
   'AI 大学 60+ プロバイダーの RSS / News フィード更新',
   'schedule', 'ps3', 'in_progress', 100, '2026-04-01', '2026-12-31', 'alpha', 'high', 0)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 5. GitHub Actions Workflow タスクを seed (instance='gha')
-- ============================================================
INSERT INTO wbs_tasks (
  category, category_icon, category_order, title, description,
  instance, owner_instance, status, progress, start_date, end_date,
  milestone_code, priority, estimated_hours
) VALUES
  ('GitHub Actions', '🔧', 9, 'deploy-prod (push to main)',
   'Flutter Web build + Supabase migrations + Firebase deploy + Push Release Tag',
   'gha', 'ps1', 'in_progress', 100, '2026-04-01', '2026-12-31', 'alpha', 'high', 0),
  ('GitHub Actions', '🔧', 9, 'ci.yml (PR check)',
   'flutter analyze + dart format + deno lint + test',
   'gha', 'ps1', 'in_progress', 100, '2026-04-01', '2026-12-31', 'alpha', 'high', 0),
  ('GitHub Actions', '🔧', 9, 'wbs-staleness-audit (毎日 06:00 JST)',
   '8 instance の wbs_tasks 更新有無監査 + cross-instance-pr 自動作成 (Win#131 part 12)',
   'gha', 'ps1', 'in_progress', 100, '2026-04-20', '2026-12-31', 'alpha', 'high', 0),
  ('GitHub Actions', '🔧', 9, 'cron-batch (1 時間ごと)',
   'horse_racing scraper / data クリーンアップ',
   'gha', 'ps6', 'in_progress', 100, '2026-04-01', '2026-12-31', 'alpha', 'medium', 0)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 6. View: マイルストーン risk 算出
-- ============================================================
CREATE OR REPLACE VIEW wbs_milestone_risk_view AS
WITH per_milestone AS (
  SELECT
    m.code,
    m.name,
    m.target_date,
    m.color,
    COUNT(t.id) AS total_tasks,
    COUNT(t.id) FILTER (WHERE t.status = 'completed') AS done_tasks,
    COUNT(t.id) FILTER (WHERE t.status != 'completed' AND t.end_date < CURRENT_DATE)
      AS overdue_tasks,
    COUNT(t.id) FILTER (WHERE t.status != 'completed') AS open_tasks,
    SUM(t.estimated_hours) FILTER (WHERE t.status != 'completed') AS remaining_hours,
    -- 残り日数
    GREATEST((m.target_date - CURRENT_DATE)::int, 0) AS days_left
  FROM wbs_milestones m
  LEFT JOIN wbs_tasks t ON t.milestone_code = m.code
  GROUP BY m.code, m.name, m.target_date, m.color
)
SELECT
  code, name, target_date, color, total_tasks, done_tasks, overdue_tasks, open_tasks,
  remaining_hours, days_left,
  -- 1 日 1 instance あたり 4h のフル稼働を仮定 (10 instance × 4h = 40h/日)
  -- 残り日数 × 40h = 利用可能工数
  (days_left * 40)::numeric AS available_hours,
  CASE
    WHEN days_left = 0 AND open_tasks > 0 THEN 'critical_overdue'
    WHEN remaining_hours IS NULL OR remaining_hours = 0 THEN 'on_track'
    WHEN remaining_hours > (days_left * 40) THEN 'over_capacity'  -- 警告
    WHEN open_tasks > 0 AND days_left < 7 THEN 'tight'
    ELSE 'on_track'
  END AS risk_status,
  -- 進捗率 (%)
  CASE
    WHEN total_tasks = 0 THEN 0
    ELSE ROUND(100.0 * done_tasks / total_tasks)
  END AS progress_pct
FROM per_milestone
ORDER BY target_date;

COMMENT ON VIEW wbs_milestone_risk_view IS 'マイルストーン risk: critical_overdue / over_capacity / tight / on_track';

-- ============================================================
-- 7. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS part 13: ALL 撲滅 + Schedule/GHA タスク seed + マイルストーン risk 警告',
  'instance 値に schedule/gha 追加 (合計 13 値)。Claude Schedule 10 タスク + GHA 4 タスク seed。estimated_hours / owner_instance 列追加。wbs_milestone_risk_view で over_capacity / tight / critical_overdue を判定。Win版#131 part 13。',
  '2026-04-20'
)
ON CONFLICT DO NOTHING;
