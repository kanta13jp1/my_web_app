-- PS#4 S141: 競合3社追加 294→297社 (reclaim-ai/sunsama/motion)
-- SEO: "Reclaim.ai代替"/"Sunsama代替"/"Motion代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S141: 競合3社追加 294→297社 (reclaim-ai/sunsama/motion)',
  'comparison_page.dartにreclaim-ai(AIスマートスケジューリング/ai-scheduler/6B4EFF)/sunsama(デイリープランナー/ai-scheduler/5C7CFA)/motion(AIタスク自動スケジュール/ai-scheduler/7C3AED)の3社追加(294→297社)。新カテゴリai-scheduler追加。sitemap 346 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
