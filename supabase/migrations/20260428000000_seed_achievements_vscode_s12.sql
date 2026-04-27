-- VSCode S12: competitor_browse_page + horse racing place_consensus UI
-- commit 53dd7af2

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'feat(vscode-s12): /competitors ブラウズページ新規 (172社グリッド + フィルタ)',
  'lib/pages/competitor_browse_page.dart 新規作成。全172社を 2/3/4列グリッドで表示。pricing_tier / japan_presence_level フィルタ + overlap/threat/name ソート。既存21社はタップで /vs-{id} 遷移。LP に「全172社を見る →」リンク追加。sitemap.xml に /competitors 追加。',
  '2026-04-28'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'feat(vscode-s12): /competitors ブラウズページ新規 (172社グリッド + フィルタ)'
);

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'feat(vscode-s12): horse racing place_consensus UI + 複勝/ワイド命中率サマリー',
  'horseracing_race_detail_page.dart: _buildConsensusBar() に複勝コンセンサス行 (place_consensus + place_distribution chips) 追加。horse_racing_predictor_page.dart: _buildBetTypeLearningSection() 内に複勝・ワイド命中率 _statCard サマリー行を Wrap の上に追加。',
  '2026-04-28'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'feat(vscode-s12): horse racing place_consensus UI + 複勝/ワイド命中率サマリー'
);
