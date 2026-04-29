-- PS#4 S159: 競合3社追加 348→351社 (jefit/mapmyrun/runkeeper)
-- SEO: "JEFIT代替"/"MapMyRun代替"/"Runkeeper代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S159: 競合3社追加 348→351社 (jefit/mapmyrun/runkeeper)',
  'comparison_page.dartにjefit(AI筋トレ計画/fitness/E63722)/mapmyrun(GPSランニング記録/fitness/004F9F)/runkeeper(AIランニングコーチ/fitness/2D90E8)の3社追加(348→351社)。全ファイル357統一。sitemap 647 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
