-- PS#4 S161: 競合3社追加 354→357社 (apple-fitness-plus/spartan/beachbody)
-- SEO: "Apple Fitness+代替"/"Spartan Race代替"/"Beachbody代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S161: 競合3社追加 354→357社 (apple-fitness-plus/spartan/beachbody)',
  'comparison_page.dartにapple-fitness-plus(Apple統合フィットネス/fitness/000000)/spartan(レース+トレーニング/fitness/C8102E)/beachbody(自宅フィットネス動画/fitness/009FDA)の3社追加(354→357社)。sitemap 400 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
