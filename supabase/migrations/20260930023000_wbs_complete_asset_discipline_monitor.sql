-- Codex #1 / 2026-09-30.
-- Issue #4902: 『借金しない宣言モニター』をWorkbookに正式追加し、違反根拠と脱却目安額を同画面表示.
-- nocheck: time-relative
-- This migration intentionally records WBS progress. Keep normal trigger and
-- constraint behavior so it runs with the standard Supabase migration role.

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Implemented discipline monitor violation evidence (balance delta, 24-month payoff line), one-shot toggle to reduce violation counts, and clear labeling for missing prior month data estimates.',
  owner_instance    = 'codex',
  start_date        = COALESCE(start_date, DATE '2026-08-26'),
  end_date          = DATE '2026-09-30',
  remaining_work    = 'Completed by Codex: added balanceDelta and 24-month payoff line in violation details, one-shot policy toggle directly on violation tile reducing violation counts, and missing prior month data estimate status labeling.',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-09-30: discipline monitor%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-09-30: discipline monitor (Codex). Implemented balance delta and 24-month payoff line on violation tiles, inline one-shot toggle for instant violation reduction, and unevaluated status labeling for missing prior month data.'
  END,
  updated_at        = now()
WHERE github_issue_number = 4902;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '『借金しない宣言モニター』に違反根拠と脱却目安額（24ヶ月ライン）を同画面表示 (#4902)',
  '資産管理画面の借金しない宣言モニターに前月比残高変動（違反根拠）と24ヶ月完済目安額を表示。違反タイル内からワンタップで「今後一括に固定」トグルを操作して次回違反数を減少可能とし、前月欠損時の推定明示を追加。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '『借金しない宣言モニター』に違反根拠と脱却目安額（24ヶ月ライン）を同画面表示 (#4902)'
);
