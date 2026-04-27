-- VSCode S11: dark mode fixes + Flutter Web focus crash guard

UPDATE public.wbs_tasks
SET
  status = 'completed',
  progress = 100,
  instance = 'vscode',
  owner_instance = 'vscode',
  updated_at = now()
WHERE id::text LIKE '32731c06%'
  AND progress < 100;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'dark mode: inventory_barcode/admin_analytics/analytics_export light-bg fix',
  'Added dark-mode guards for inventory_barcode, admin_analytics, and analytics_export surfaces so light background chips/cards do not break contrast.',
  '2026-04-27'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.development_achievements
  WHERE title = 'dark mode: inventory_barcode/admin_analytics/analytics_export light-bg fix'
);

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'fix(web): Flutter Web focus traversal RenderBox layout error guard',
  'Added Dart and bootstrap-level guards for non-fatal Flutter Web focus traversal and InkResponse framework races that surfaced as uncaught console errors.',
  '2026-04-27'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.development_achievements
  WHERE title = 'fix(web): Flutter Web focus traversal RenderBox layout error guard'
);
