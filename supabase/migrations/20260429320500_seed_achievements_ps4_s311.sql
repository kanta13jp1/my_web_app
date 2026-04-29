-- PS#4 S311: 競合3社追加 804→807社 (betterworks/leapsome/bullhorn)
-- SEO: "BetterWorks代替"/"Leapsome代替"/"Bullhorn代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S311: 競合3社追加 804→807社 (betterworks/leapsome/bullhorn)',
  'comparison_page.dartにbetterworks(OKR目標管理継続パフォーマンス/hrtech/0369A1)/leapsome(AIパワードパフォーマンス学習/hrtech/7C3AED)/bullhorn(人材派遣スタッフィングCRM/hrtech/E8480C)の3社追加(804→807社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
