-- Session daily-development 2026-04-03: 語学学習・Edge Function Summary Card修正
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '語学学習ページ実装 (Duolingo/Anki競合)',
    'language_learning_page.dartを新規作成。language-learning Edge Functionと連携。単語帳管理・SM-2間隔反復フラッシュカードレビュー・連続学習ストリーク・統計の3タブ構成。12言語対応。flutter analyze 0件維持。',
    '2026-04-03'
  ),
  (
    'Edge Function Summary Card 修正・整合性確保',
    'recipe-meal-planner/travel-itinerary-planner/spreadsheet-databaseの実装済みエントリをfalse→trueに修正。重複エントリを削除。horse-racing-predictor/language-learning/crm-sales-pipelineの新規エントリを追加。UI実装カバレッジの正確性向上。',
    '2026-04-03'
  )
ON CONFLICT DO NOTHING;
