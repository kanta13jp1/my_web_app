-- Codex #1 / 2026-09-30.
-- Issue #4901: リボカード照合のUI分岐と説明強化（不一致アラート抑止＋確定額ロジック明示）.
-- nocheck: time-relative
-- This migration intentionally records WBS progress. Keep normal trigger and
-- constraint behavior so it runs with the standard Supabase migration role.

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Implemented revolving badge and explanation tooltip on card statement reconciliation table, suppressed mismatch alerts for revolving cards, and verified non-revolving cards retain unimported alerts.',
  owner_instance    = 'codex',
  start_date        = COALESCE(start_date, DATE '2026-08-26'),
  end_date          = DATE '2026-09-30',
  remaining_work    = 'Completed by Codex: added revolving badge with tooltip in card statement reconciliation table, suppressed mismatch alerts for revolving cards while showing determined payment rule notes, and added unit/widget tests.',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-09-30: card reconciliation revolving UI%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-09-30: card reconciliation revolving UI (Codex). Implemented revolving badge and tooltip on reconciliation table, confirmed alert suppression for revolving cards, and preserved warnings for non-revolving cards.'
  END,
  updated_at        = now()
WHERE github_issue_number = 4901;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'リボカード照合のUI分岐と説明強化（不一致アラート抑止＋確定額ロジック明示） (#4901)',
  '資産管理画面のカード明細照合テーブルにおいて、リボ払いカードに「リボ」バッジと説明ツールチップを実装。不一致アラートを抑止し確定額ロジックを表示する一方、非リボカードの未取込警告を維持。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'リボカード照合のUI分岐と説明強化（不一致アラート抑止＋確定額ロジック明示） (#4901)'
);
