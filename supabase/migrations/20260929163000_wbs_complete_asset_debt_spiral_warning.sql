-- Codex #1 / 2026-09-29.
-- Issue #5366: 利息が元金返済額を上回る負債に対する早期警告と対策提案機能 (利息スパイラル警告).
-- nocheck: time-relative
-- This migration intentionally records WBS progress. Keep normal trigger and
-- constraint behavior so it runs with the standard Supabase migration role.

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Implemented deterministic debtSpiralWarning action item generation in AssetManagementInsightService, added 24-month payoff target calculation and duration simulation, wired jump action in AssetManagementPage UI, and updated tests.',
  owner_instance    = 'codex',
  start_date        = COALESCE(start_date, DATE '2026-09-08'),
  end_date          = DATE '2026-09-29',
  remaining_work    = 'Completed by Codex: added debtSpiralWarning for debts where principal payment <= interest or zero, calculating 24-month payoff amounts and duration simulation.',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-09-29: debt spiral warning%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-09-29: debt spiral warning (Codex). Implemented early detection of debt spiral condition (zero principal payment or principal payment <= monthly interest) with 24-month payoff target and simulation, wired to ActionItems UI.'
  END,
  updated_at        = now()
WHERE github_issue_number = 5366;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '利息が元金返済額を上回る負債に対する早期警告と対策提案機能 (#5366)',
  '資産管理画面に「利息スパイラル警告」（元金返済0円または利息過多負債の早期発見）を実装。24ヶ月完済目標額の概算提示、現行ペースでの完済年数および追加利息のシミュレーション、UIジャンプ導線を完了。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '利息が元金返済額を上回る負債に対する早期警告と対策提案機能 (#5366)'
);
