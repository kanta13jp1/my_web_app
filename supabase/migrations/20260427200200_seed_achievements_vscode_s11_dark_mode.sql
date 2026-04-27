-- VSCode S11: dark mode fixes — inventory_barcode/admin_analytics/analytics_export + Flutter Web focus crash guard

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
    'dark mode: inventory_barcode/admin_analytics/analytics_export light-bg fix',
    'inventory_barcode_page の低在庫カード(FFEBEE)、admin_analytics_page の登録目標グラデーション(E8F5E9/FFEBEE)・ユーザー一覧CircleAvatar(E8F5E9/E8EAF6)・ダイアログChip(E3F2FD)・機能リクエストランク(FEF3C7)、analytics_export_page のチップ(E0F2F1/B2DFDB)にisDarkガード追加。DESIGN.md全ページ準拠WBSタスク完結。',
    '2026-04-27'
  ),
  (
    'fix(web): Flutter Web focus traversal RenderBox layout error guard',
    'error_reporter.dart に _isIgnorableFlutterWebFocusTraversalLayoutError を追加。web/index.html に window.error filter でisFocusTraversalRenderBox/isInkResponseNull をpreventDefault。非致命的フレームワーク競合エラーを抑制。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
