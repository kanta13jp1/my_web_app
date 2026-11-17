-- Codex #1 / 2026-09-29.
-- Issue #2492: 確定申告export (CSV+e-Tax形式) UI連携完了.
-- nocheck: time-relative
-- This migration intentionally records WBS progress. Keep normal trigger and
-- constraint behavior so it runs with the standard Supabase migration role.

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Wired deterministic AssetTaxExportService to AssetManagementPage UI with tax year selection, preview totals, warnings display, and dual downloads (CSV + e-Tax XML skeleton). Tests updated. Validated via CI.',
  owner_instance    = 'codex',
  start_date        = COALESCE(start_date, DATE '2026-07-13'),
  end_date          = DATE '2026-09-29',
  remaining_work    = 'Completed by Codex: UI export dialog wired to AssetManagementPage with CSV and e-Tax XML downloads, workbook record extraction, and comprehensive tests.',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-09-29: tax export wired to asset UI%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-09-29: tax export wired to asset UI (Codex). Wired deterministic AssetTaxExportService to AssetManagementPage UI with tax year selection, preview summary, warnings display, and dual downloads (CSV + e-Tax XML skeleton). Added extractRecordsFromWorkbook helper.'
  END,
  updated_at        = now()
WHERE id = 'c188e792-6c81-4973-b667-396a7ddcb046'
   OR github_issue_number = 2492;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '確定申告export (CSV+e-Tax形式) UI連携完了 (#2492)',
  '資産管理画面に確定申告エクスポート機能（CSV + e-Tax XMLスケルトン）を連携。対象年度選択、所得・経費・控除のプレビュー集計、警告検証、およびブラウザダウンロード導線を実装完了。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '確定申告export (CSV+e-Tax形式) UI連携完了 (#2492)'
);
