-- WBS update — #1125 Build in Public Phase 2 完了 = 100% (Win版#132 part 113 / 2026-05-01)

-- nocheck: time-relative
-- Safe: this migration marks the touched WBS rows completed, so
-- wbs_enforce_recovery_plan() returns before CURRENT_DATE checks run.
UPDATE wbs_tasks
SET status = 'completed',
    progress = 100,
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 113] Phase 2 完了 = .github/workflows/build-in-public-extract.yml weekly cron (= 金曜 03:00 UTC) 追加. INDIE_DEV_VELOCITY #7 actual 自走化. Phase 3 PS#2 連携は別 cross-instance-pr 候補.'
WHERE github_issue_number = 1125;

UPDATE wbs_tasks
SET status = 'completed',
    progress = 100,
    description = COALESCE(description, '') || E'\n\n[part 113] weekly cron 化完了 = #1125 Phase 2 = 100% / weekly 金曜 cron 自走.'
WHERE title = '[INDIE_DEV_VELOCITY #7 dogfood] build_in_public_extract.py + future weekly cron';

INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'Win132 part 113: Build in Public weekly cron 完了 (#1125 = 100%)',
  'Phase 6 自律 cycle 第 5 例. .github/workflows/build-in-public-extract.yml weekly cron (= 金曜 03:00 UTC = 12:00 JST) で scripts/build_in_public_extract.py 自走化. WBS Issue #1125 = 100% completed. INDIE_DEV_VELOCITY #7 (Community Engagement Discipline) full cycle 自走 (= ROADMAP-LOG → dev.to draft + X 短文 + summary 自動生成 weekly). Phase 3 PS#2 dispatch 連携は cross-instance-pr 候補.',
  '2026-05-01'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements
  WHERE title = 'Win132 part 113: Build in Public weekly cron 完了 (#1125 = 100%)'
);
