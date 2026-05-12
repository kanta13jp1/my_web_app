-- PS#4 S121: 競合3社追加 234→237社 (jira/wrike/sketch)
-- SEO: "Jira代替"/"Wrike代替"/"Sketch代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S121: 競合3社追加 234→237社 (jira/wrike/sketch)',
  'comparison_page.dartにjira(アジャイルイシュートラッカー/project/0052CC)/wrike(エンタープライズPM/project/20B44B)/sketch(Mac向けUIデザイン/design/FDB300)の3社追加。新カテゴリhosting/design追加。competitorMeta/sitemap/_categoryOf更新。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
