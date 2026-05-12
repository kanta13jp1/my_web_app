-- WBS update — #1125 Build in Public 自動化 Phase 1 完了 (Win版#132 part 112 / 2026-05-01)

UPDATE wbs_tasks
SET status = 'in_progress',
    progress = 50,
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 112] scripts/build_in_public_extract.py 実装 (~150 行 / ROADMAP-LOG + memory/log.md から直近 N 日 extract / dev.to draft + X 短文 + summary 生成 / INDIE #7 dogfood). 動作確認済 (= 162 ROADMAP + 57 log entries 処理). 残: weekly cron 化 + PS#2 dispatch 連携.'
WHERE github_issue_number = 1125;

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, description)
SELECT
  '[INDIE_DEV_VELOCITY #7 dogfood] build_in_public_extract.py + future weekly cron',
  'CX',
  'win',
  'win',
  'medium',
  'in_progress',
  50,
  'Win版#132 part 112 で実装. WBS Issue #1125 Phase 1. ROADMAP-LOG + memory/log.md 直近 N 日を dev.to draft + X 短文 + summary に変換. 残: GHA workflow weekly cron + PS#2 T-1 dispatch routine 連携.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '[INDIE_DEV_VELOCITY #7 dogfood] build_in_public_extract.py + future weekly cron'
);

INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'Win132 part 112: Build in Public 自動化 Phase 1 (#1125)',
  'Phase 6 自律 cycle 第 4 例. scripts/build_in_public_extract.py 新規 (~150 行 / INDIE #7 dogfood). ROADMAP-LOG (= 162 entries) + memory/log.md (= 57 entries) を dev.to draft + X 短文 + summary に変換. CEO 承認 → publish フロー想定. 残: weekly cron + PS#2 連携.',
  '2026-05-01'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements
  WHERE title = 'Win132 part 112: Build in Public 自動化 Phase 1 (#1125)'
);
