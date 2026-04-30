-- WBS update — Top 10 期限超過 task triage (Win版#132 part 103 / 2026-04-30)
--
-- User 5 度目要望「上から順番に進めて / 対応不能は報告」契機.
-- /project-gantt 上位 12 task を Win territory で triage:
--   - Win 直接実装 2 件 (#1267 / #926)
--   - cross-instance-pr handoff 9 件
--
-- N-time alarm Phase 5 = 「明示遵守 + 透明 handoff」phase dogfood.

-- ==============================================
-- 1. Win 直接実装完了 (= 100%)
-- ==============================================

UPDATE wbs_tasks
SET status = 'completed',
    progress = 100
WHERE github_issue_number = 1267;

UPDATE wbs_tasks
SET status = 'completed',
    progress = 100
WHERE github_issue_number = 926;

-- ==============================================
-- 2. handoff 済み (= cross-instance-pr 起票で 10% に進める)
--    docs/cross-instance-prs/20260430_top10_expired_tasks_batch_handoff.md
-- ==============================================

UPDATE wbs_tasks
SET status = 'in_progress',
    progress = 10,
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 103] cross-instance-pr handoff 起票済 (= docs/cross-instance-prs/20260430_top10_expired_tasks_batch_handoff.md). Codex#2 territory で MCP_AUTH 拡張対応.'
WHERE github_issue_number IN (845, 846, 1268, 1036, 1037, 1123);

UPDATE wbs_tasks
SET status = 'in_progress',
    progress = 10,
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 103] cross-instance-pr handoff 起票済. VSCode territory で UI 系実装.'
WHERE github_issue_number IN (1265, 1269, 1124);

-- ==============================================
-- 3. AI_FLEET_SYNERGY infrastructure (= part 103 で actual 動作確認)
-- ==============================================

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, description)
SELECT
  '[AI_FLEET_SYNERGY #1 拡張] instance_conflict_predictor.py monthly cron',
  'CX',
  'codex2',
  'codex2',
  'medium',
  'pending',
  20,
  'Win版#132 part 103 で本 script 実装済 (= scripts/instance_conflict_predictor.py / 直近 24h commit から file overlap + migration cluster + risk H/M/L 算出 / docs/instance-conflict/<YYYY-MM-DD>.md 出力). Codex#2 territory で monthly GHA workflow 化 (= 既存 instance-role-audit.yml と同型).'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '[AI_FLEET_SYNERGY #1 拡張] instance_conflict_predictor.py monthly cron'
);

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, description)
SELECT
  '[N-time alarm Phase 5] Top expired tasks batch handoff cross-instance-pr',
  'CX',
  'win',
  'win',
  'high',
  'completed',
  100,
  'Win版#132 part 103 で完了 (= docs/cross-instance-prs/20260430_top10_expired_tasks_batch_handoff.md). 上位 11 期限超過 task を 4 instance に明示 routing. N-time alarm Phase 5 (= 明示遵守 + 透明 handoff) dogfood.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '[N-time alarm Phase 5] Top expired tasks batch handoff cross-instance-pr'
);

-- ==============================================
-- 4. production console errors (= P0 / VSCode handoff)
-- ==============================================

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, description)
SELECT
  '[P0] production console errors (Null check / Noto fonts / minified:nl<void>) 調査 + fix',
  'CX',
  'vscode',
  'vscode',
  'high',
  'pending',
  0,
  'Win版#132 part 103 screenshot で観察. main.dart.js:4079 周辺 + Object.aa の null deref. flutter run --release --no-tree-shake-icons で再現 + integration test 強化. VIBE_CODING #5 (Minimal E2E Tests) dogfood. cross-instance-pr docs/cross-instance-prs/20260430_top10_expired_tasks_batch_handoff.md §4 参照.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '[P0] production console errors (Null check / Noto fonts / minified:nl<void>) 調査 + fix'
);

-- ==============================================
-- 5. development_achievements 追加
-- ==============================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win版#132 part 103: Top 10 期限超過 task triage + N-time alarm Phase 5 dogfood',
  'User 5 度目要望「上から順番に / 対応不能は報告」契機. /project-gantt screenshot 918 tasks 上位 12 を triage. Win 直接実装 2 件 (#926 instance_conflict_predictor.py = High risk 検出 / #1267 docs/CLAUDE_CODE_SESSION_PREFIX.md = jibun- prefix convention) + 9 件 cross-instance-pr handoff (= MCP_AUTH 2 / 対話リモート 1 / schedule-hub EF 2 / LRM 1 / オフライン UI 1 / 食生活 1 / GPA UI 1) + production console errors P0 を VSCode 委譲. N-time alarm Phase 5 (= 明示遵守 + 透明 handoff) docs/N_TIME_ALARM_PATTERN.md 追記.',
  '2026-04-30'
)
ON CONFLICT DO NOTHING;
