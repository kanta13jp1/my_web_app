-- Codex #1 / 2026-09-29.
-- Issue #5372: リボ払い新規利用の内訳可視化と誓約達成状況の連動.
-- nocheck: time-relative
-- This migration intentionally records WBS progress. Keep normal trigger and
-- constraint behavior so it runs with the standard Supabase migration role.

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Implemented revolving credit new usage breakdown and statement lines integration, covered vs uncovered shortfall status calculation, linked discipline pledge 2 evidence and UI expansion with card statement import prompt, and updated tests.',
  owner_instance    = 'codex',
  start_date        = COALESCE(start_date, DATE '2026-09-08'),
  end_date          = DATE '2026-09-29',
  remaining_work    = 'Completed by Codex: added revolving new usage breakdown UI, statement lines linking, status badges (covered/uncovered), discipline pledge 2 evidence linkage, and statement import prompts.',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-09-29: revolving usage breakdown%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-09-29: revolving usage breakdown (Codex). Implemented revolving usage breakdown items, status calculation, debt trend UI expansion, discipline monitor pledge 2 evidence linkage, and import prompts.'
  END,
  updated_at        = now()
  WHERE github_issue_number = 5372;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'リボ払い新規利用の内訳可視化と誓約達成状況の連動 (#5372)',
  '資産管理画面の負債トレンドおよび借金しない宣言モニター（誓約②）に、リボ払い新規利用の具体的な明細内訳と返済カバー状況（リボ算入・返済不足等）の可視化UIを実装。カード明細未取込時の案内と取込誘導導線を整備。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'リボ払い新規利用の内訳可視化と誓約達成状況の連動 (#5372)'
);
