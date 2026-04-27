-- VSCode S10: cross-instance-pr 2件完了
-- 1. comparison_page.dart: const map → Supabase fetch overlay (pricing + japan_presence バッジ)
-- 2. user_tasks_page.dart: wbs.user_task_report + blockers/next_action フィールド追加

UPDATE public.wbs_tasks
SET
  status        = 'completed',
  progress      = 100,
  instance      = 'vscode',
  owner_instance = 'vscode',
  updated_at    = now()
WHERE id::text LIKE '32731c06%'
  AND progress < 100;

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES
  (
    'comparison_page: Supabase pricing/japan_presence overlay',
    'ComparisonPage を StatefulWidget 化し competitors テーブルから pricing_tier / pricing_start_usd / japan_presence_level を非同期 fetch。ヒーローセクションに _PricingBadge / _JapanPresenceBadge を表示。フォールバック付き。',
    '2026-04-27'
  ),
  (
    'user_tasks_page: wbs.user_task_report + blockers/next_action',
    '報告 EF を wbs.update_user_task_report → wbs.user_task_report に移行。ダイアログに blockers / next_action フィールド追加。タスクカードに latest_report.next_action を表示。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
