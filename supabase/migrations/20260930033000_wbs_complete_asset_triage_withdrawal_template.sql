-- Codex #1 / 2026-09-30.
-- Issue #4903: 『今日やることトリアージ』に出金/移動テンプレ（1万/2万）を実装し、生活費先取りをワンタップ化.
-- nocheck: time-relative
-- This migration intentionally records WBS progress. Keep normal trigger and
-- constraint behavior so it runs with the standard Supabase migration role.

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Implemented 10k/20k living expense withdrawal templates in asset triage, immediate transfer task generation, live balance recalculation, duplicate prevention, and failure rollback.',
  owner_instance    = 'codex',
  start_date        = COALESCE(start_date, DATE '2026-08-26'),
  end_date          = DATE '2026-09-30',
  remaining_work    = 'Completed by Codex: added 10k/20k living expense withdrawal templates in triage, instant transferTask generation, live expected balance recalculation, and comprehensive cloud visual and integration test coverage.',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-09-30: triage withdrawal template%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-09-30: triage withdrawal template (Codex). Implemented 10k/20k withdrawal templates in triage, transferTask generation, immediate balance recalculation, duplicate prevention, and visual regression verification.'
  END,
  updated_at        = now()
WHERE github_issue_number = 4903;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '『今日やることトリアージ』に出金/移動テンプレ（1万/2万）を実装し、生活費先取りをワンタップ化 (#4903)',
  '生活費トリアージにおいて、今日の使用可能額マイナス時または手元現金不足時に1万円／2万円の予定出金テンプレートを提示し、ワンタップで振替タスク登録・見込み残高即時再計算・二重登録防止・ロールバックを実装。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '『今日やることトリアージ』に出金/移動テンプレ（1万/2万）を実装し、生活費先取りをワンタップ化 (#4903)'
);
