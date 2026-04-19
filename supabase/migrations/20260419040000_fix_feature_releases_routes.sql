-- Win版#110: feature_releases の feature_route を main.dart に存在するルートに修正
-- 問題: 「最近追加された機能」リストをタップしても LandingPage に飛ばされていた
-- 原因: feature_releases.feature_route が main.dart の onGenerateRoute に未登録
--       → Flutter Web SPA fallback で / に戻る
-- 対応:
--   - /ai-university → /gemini-university (既存ルート)
--   - /wbs           → /gantt-timeline    (既存ルート・GanttTimelinePage = WBS)
--   - /note-list     → 本マイグレーション + main.dart に新規追加で正しく動作
--   - /ai-provider-status → 既に正しい

UPDATE feature_releases
SET feature_route = '/gemini-university'
WHERE feature_route = '/ai-university';

UPDATE feature_releases
SET feature_route = '/gantt-timeline'
WHERE feature_route = '/wbs';

-- /note-list はそのまま (main.dart 側で route 追加済 = Win版#110 commit)
-- /ai-provider-status はそのまま (既に正しい)
