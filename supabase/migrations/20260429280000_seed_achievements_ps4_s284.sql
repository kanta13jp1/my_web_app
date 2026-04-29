-- PS#4 S284: 競合3社追加 723→726社 (mindtickle/360learning/learnupon)
-- SEO: "Mindtickle代替"/"360Learning代替"/"LearnUpon代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S284: 競合3社追加 723→726社 (mindtickle/360learning/learnupon)',
  'comparison_page.dartにmindtickle(セールストレーニングAI分析/sales/5C30C2)/360learning(コラボレーティブLMSピアラーニング/education/00C4D4)/learnupon(多ポータルLMS社員顧客研修/education/0065BD)の3社追加(723→726社)。sitemap 769 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
