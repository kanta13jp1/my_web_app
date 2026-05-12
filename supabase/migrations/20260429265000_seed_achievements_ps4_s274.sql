-- PS#4 S274: 競合3社追加 693→696社 (pluralsight/linkedin-learning/udacity)
-- SEO: "Pluralsight代替"/"LinkedIn Learning代替"/"Udacity代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S274: 競合3社追加 693→696社 (pluralsight/linkedin-learning/udacity)',
  'comparison_page.dartにpluralsight(IT技術者スキル開発/learning/EF3D59)/linkedin-learning(LinkedIn統合プロ動画学習/learning/0A66C2)/udacity(ナノディグリーAI就職保証/learning/02B3E4)の3社追加(693→696社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
