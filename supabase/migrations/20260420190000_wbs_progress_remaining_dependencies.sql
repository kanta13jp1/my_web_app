-- WBS 拡張 part 20: 進捗率/残作業/依存関係列追加 + 残 ALL 一括 reassign + AI 概観 (Win版#131 part 20)

-- ============================================================
-- 1. 列追加
-- ============================================================
ALTER TABLE wbs_tasks
  ADD COLUMN IF NOT EXISTS remaining_work text DEFAULT '',
  ADD COLUMN IF NOT EXISTS depends_on uuid[] DEFAULT '{}'::uuid[],
  ADD COLUMN IF NOT EXISTS depends_on_titles text[] DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS auto_recovery_applied boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN wbs_tasks.remaining_work IS '完了に必要な残作業内容 (例: "Stripe webhook 実装 + RLS 確認")';
COMMENT ON COLUMN wbs_tasks.depends_on IS '依存タスク UUID 配列 (このタスクは指定タスク完了後に着手)';
COMMENT ON COLUMN wbs_tasks.depends_on_titles IS 'depends_on のタスクタイトル配列 (UI 表示用 cache)';
COMMENT ON COLUMN wbs_tasks.auto_recovery_applied IS 'スケジュール自動修復適用済フラグ';

-- ============================================================
-- 2. 残 'all' タスク bulk reassign — title pattern based
-- ============================================================

-- 死んでた / 復活 系 → win
UPDATE wbs_tasks SET instance = 'win', owner_instance = 'win'
  WHERE instance = 'all' AND (title LIKE '%死んでた%' OR title LIKE '%復活%');

-- WF / health / deploy / CI / orphan / GHA 系 → ps1
UPDATE wbs_tasks SET instance = 'ps1', owner_instance = 'ps1'
  WHERE instance = 'all' AND (
    title LIKE '%WF%' OR title LIKE '%workflow%' OR title LIKE '%health%' OR
    title LIKE '%deploy%' OR title LIKE '%CI%' OR title LIKE '%orphan%' OR
    title LIKE '%Rule17%' OR title LIKE '%secret%' OR title LIKE '%BYPASS%' OR
    title LIKE '%GH_PAT%' OR title LIKE '%GHA%'
  );

-- AI 大学 / provider / プロバイダー / ai-hub / マルチモーダル / 画像生成 / 課金 → win
UPDATE wbs_tasks SET instance = 'win', owner_instance = 'win'
  WHERE instance = 'all' AND (
    title LIKE '%AI%' OR title LIKE '%provider%' OR title LIKE '%プロバイダー%' OR
    title LIKE '%hub%' OR title LIKE '%マルチモーダル%' OR title LIKE '%画像生成%' OR
    title LIKE '%課金%' OR title LIKE '%Stripe%' OR title LIKE '%Notion%' OR
    title LIKE '%Asana%' OR title LIKE '%MoneyForward%' OR title LIKE '%Evernote%' OR
    title LIKE '%Slack%'
  );

-- DESIGN / UI / モバイル / レスポンシブ → vscode
UPDATE wbs_tasks SET instance = 'vscode', owner_instance = 'vscode'
  WHERE instance = 'all' AND (
    title LIKE '%DESIGN%' OR title LIKE '%UI%' OR title LIKE '%モバイル%' OR
    title LIKE '%レスポンシブ%' OR title LIKE '%LP%' OR title LIKE '%SEO%' OR
    title LIKE '%タイポグラフィ%' OR title LIKE '%ストリーク%' OR title LIKE '%バッジ%'
  );

-- T-1 / blog / dispatch / Qiita / dev.to → ps2
UPDATE wbs_tasks SET instance = 'ps2', owner_instance = 'ps2'
  WHERE instance = 'all' AND (
    title LIKE '%T-1%' OR title LIKE '%blog%' OR title LIKE '%ブログ%' OR
    title LIKE '%dispatch%' OR title LIKE '%Qiita%' OR title LIKE '%dev.to%'
  );

-- 競合 / モニタリング → ps4
UPDATE wbs_tasks SET instance = 'ps4', owner_instance = 'ps4'
  WHERE instance = 'all' AND (
    title LIKE '%競合%' OR title LIKE '%モニタリング%'
  );

-- on-call / バグ修正 / EF urgent → ps5
UPDATE wbs_tasks SET instance = 'ps5', owner_instance = 'ps5'
  WHERE instance = 'all' AND (
    title LIKE '%on-call%' OR title LIKE '%バグ%' OR
    title LIKE '%EF cleanup%' OR title LIKE '%EF urgent%'
  );

-- 競馬 / horse_racing → ps6
UPDATE wbs_tasks SET instance = 'ps6', owner_instance = 'ps6'
  WHERE instance = 'all' AND (
    title LIKE '%競馬%' OR title LIKE '%horse%' OR title LIKE '%netkeiba%'
  );

-- 残った 'all' = ユーザー数 50/500/5000 のみ
-- これらは全 instance 共同責任なので 'all' のまま (UI で red 警告色)

-- ============================================================
-- 3. recovery_plan 未入力タスクへの bulk fill
-- ============================================================
UPDATE wbs_tasks
  SET recovery_plan = CASE
    WHEN status = 'completed' THEN ''
    WHEN end_date < CURRENT_DATE AND (recovery_plan IS NULL OR recovery_plan = '') THEN
      '⏰ 自動: 担当 instance で次セッション最優先 / 必要なら end_date リスケ'
    WHEN status != 'completed' AND (recovery_plan IS NULL OR recovery_plan = '') THEN
      '計画通り進行中 (遅延発生時のみ更新必要)'
    ELSE recovery_plan
  END
  WHERE status != 'completed';

-- ============================================================
-- 4. remaining_work 未入力 → 簡易 description コピー
-- ============================================================
UPDATE wbs_tasks
  SET remaining_work = CASE
    WHEN status = 'completed' THEN ''
    WHEN remaining_work IS NULL OR remaining_work = '' THEN
      COALESCE(NULLIF(description, ''), '残作業未記入 — 担当 instance で wbs.update_progress 経由で記入')
    ELSE remaining_work
  END
  WHERE status != 'completed';

-- ============================================================
-- 5. AI 概観 view — プロジェクト健全性 snapshot
-- ============================================================
CREATE OR REPLACE VIEW wbs_project_overview_view AS
SELECT
  COUNT(*)                                               AS total_tasks,
  COUNT(*) FILTER (WHERE status = 'completed')           AS done_tasks,
  COUNT(*) FILTER (WHERE status = 'in_progress')         AS in_progress_tasks,
  COUNT(*) FILTER (WHERE status = 'pending')             AS pending_tasks,
  COUNT(*) FILTER (WHERE status = 'blocked')             AS blocked_tasks,
  COUNT(*) FILTER (
    WHERE status != 'completed' AND end_date < CURRENT_DATE
  )                                                      AS overdue_tasks,
  COUNT(*) FILTER (
    WHERE status != 'completed' AND end_date < CURRENT_DATE
      AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0)
  )                                                      AS overdue_no_recovery,
  COUNT(DISTINCT instance) FILTER (WHERE instance != 'all') AS active_instances,
  ROUND(AVG(progress) FILTER (WHERE status = 'in_progress')) AS avg_in_progress_pct,
  -- 担当別 distribution
  jsonb_object_agg(instance, instance_count) FILTER (WHERE instance_count IS NOT NULL) AS by_instance
FROM (
  SELECT *,
    COUNT(*) OVER (PARTITION BY instance) AS instance_count
  FROM wbs_tasks
) sub;

COMMENT ON VIEW wbs_project_overview_view IS 'AI 概観報告用: タスク総数 / 進捗 / 遅延 / 担当分布';

-- ============================================================
-- 6. 依存関係 自動修復 function
-- ============================================================
-- 依存先のタスクの end_date より start_date が早い場合、自動的に
-- start_date = max(depends_on.end_date) + 1 day に調整
CREATE OR REPLACE FUNCTION wbs_auto_repair_dependencies()
RETURNS TABLE (
  task_id uuid,
  task_title text,
  old_start date,
  new_start date,
  trigger_dependency text
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH dep_max AS (
    SELECT
      t.id,
      t.title,
      t.start_date AS old_start,
      MAX(d.end_date) AS dep_end_max,
      array_agg(d.title ORDER BY d.end_date DESC) AS dep_titles
    FROM wbs_tasks t
    JOIN LATERAL unnest(t.depends_on) AS dep_id ON TRUE
    JOIN wbs_tasks d ON d.id = dep_id
    WHERE t.depends_on IS NOT NULL
      AND array_length(t.depends_on, 1) > 0
      AND t.status != 'completed'
      AND d.end_date IS NOT NULL
    GROUP BY t.id, t.title, t.start_date
  )
  UPDATE wbs_tasks tk
  SET start_date = dm.dep_end_max + 1,
      auto_recovery_applied = true,
      updated_at = now()
  FROM dep_max dm
  WHERE tk.id = dm.id
    AND (tk.start_date IS NULL OR tk.start_date <= dm.dep_end_max)
  RETURNING dm.id, dm.title, dm.old_start, tk.start_date, dm.dep_titles[1];
END;
$$;

COMMENT ON FUNCTION wbs_auto_repair_dependencies IS '依存関係自動修復: depends_on のタスク完了日より早い start_date を持つタスクを後ろ倒し';

-- ============================================================
-- 7. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS part 20: 進捗率/残作業/依存関係列 + 残 ALL bulk reassign + AI 概観 + 自動修復',
  'wbs_tasks に remaining_work / depends_on / depends_on_titles / auto_recovery_applied 列追加。残 all タスクを title pattern で 8 instance に bulk reassign (ユーザー数達成のみ all 残置)。recovery_plan / remaining_work 未入力フォールバック。wbs_project_overview_view (AI 概観用)。wbs_auto_repair_dependencies() function (依存関係自動修復)。Win版#131 part 20。',
  '2026-04-20'
)
ON CONFLICT DO NOTHING;
