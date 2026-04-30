-- WBS update — Top 11-22 期限超過 task triage (Win版#132 part 104 / 2026-05-01)
--
-- User 6 度目要望 = N-time alarm Phase 6 「定常自律実行」 dogfood.
-- Phase 5 template が確立済 → next layer 自動 triage.

-- ==============================================
-- 1. Top 11-22 handoff progress (= 0% → 10%)
-- ==============================================

UPDATE wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 104] Phase 6 自律 triage 第 2 弾 / cross-instance-pr docs/cross-instance-prs/20260501_top11to22_expired_tasks_batch_handoff.md 起票 / VSCode UI 委譲.'
WHERE github_issue_number IN (1270, 1272, 1274);

UPDATE wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 104] Phase 6 自律 triage 第 2 弾 / VSCode + Codex#2 並列 (UI + EF) 委譲.'
WHERE github_issue_number IN (1271, 1404);

UPDATE wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 104] Win 担当候補 (= 後続 part で着手) / NotebookLM 蒸留 routine cron 化 + 競合モニタリング統合.'
WHERE github_issue_number = 1405;

UPDATE wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 104] Win 担当候補 / SECOND_BRAIN 軸 ingest pipeline 設計 + Obsidian 互換化.'
WHERE github_issue_number = 974;

UPDATE wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 104] PS#1 既委譲済 (consolidate-memory --lint / part 69 cross-instance-pr) の進捗 follow up + log.md auto-maintain 拡張.'
WHERE github_issue_number = 976;

UPDATE wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 104] INDIE_DEV_VELOCITY #7 dogfood / Build in Public 自動化 (ROADMAP-LOG → dev.to/X) / PS#2 連携.'
WHERE github_issue_number = 1125;

-- ==============================================
-- 2. Phase 6 自律実行 task として記録
-- ==============================================

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, description)
SELECT
  '[N-time alarm Phase 6] 定常自律実行 — fleet 成熟期 entry',
  'CX',
  'win',
  'win',
  'high',
  'completed',
  100,
  'Win版#132 part 104 で Phase 6 確立 + dogfood. User 6 度目同一要望 = template 確立済の定常運用 signal. AI fleet が User reminder なしで自走する成熟期 entry. docs/N_TIME_ALARM_PATTERN.md Phase 6 セクション追記.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '[N-time alarm Phase 6] 定常自律実行 — fleet 成熟期 entry'
);

-- ==============================================
-- 3. development_achievements
-- ==============================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win版#132 part 104: N-time alarm Phase 6「定常自律実行」確立 + Top 11-22 batch triage',
  'User 6 度目要望 → N-time alarm rule 第 7 適用 = Phase 6 「定常自律実行」phase 確立. AI fleet が template 確立済の成熟期に入り、User reminder なしで自走 cycle を回す状態. cross-instance-pr docs/cross-instance-prs/20260501_top11to22_expired_tasks_batch_handoff.md (= 13-22 位 batch handoff / VSCode 4 件 + Codex#2 2 件 + Win 候補 4 件 + PS#1 #2 連携). docs/N_TIME_ALARM_PATTERN.md Phase 6 セクション追記.',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
