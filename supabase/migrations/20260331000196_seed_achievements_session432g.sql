-- Session 432g: ライフスタイルEdge Functions (写真/音楽/レシピ/フィットネス/旅行)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('写真ギャラリー管理 Edge Function', 'Google Photos/Facebook/LINE競合: アルバム作成、AI自動タグ付け、タイムライン表示、共有アルバム、タグ統計', '2026-03-31'),
  ('音楽プレイリスト管理 Edge Function', 'Amazon Music/Liven競合: プレイリスト作成、楽曲管理 (12ジャンル)、再生履歴、お気に入り、ジャンルレコメンド', '2026-03-31'),
  ('レシピ・献立プランナー Edge Function', 'Amazon Fresh/Liven競合: レシピ管理 (9カテゴリ)、週間献立計画、買い物リスト自動生成、栄養計算', '2026-03-31'),
  ('フィットネス・健康管理 Edge Function', 'Google Fit競合: ワークアウト記録 (10種目)、体重・体組成記録、健康メトリクス、目標設定、週次サマリー', '2026-03-31'),
  ('旅行プランナー Edge Function', 'Google Maps/Notion競合: 旅行プラン作成、日程別アクティビティ、予約管理 (8タイプ)、パッキングリスト、予算管理', '2026-03-31')
ON CONFLICT DO NOTHING;
