-- PS#4 S335: 競合3社追加 876→879社 (scale-ai/snorkel-ai/activeloop)
-- SEO: "Scale AI代替"/"Snorkel AI代替"/"Activeloop代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S335: 競合3社追加 876→879社 (scale-ai/snorkel-ai/activeloop)',
  'comparison_page.dartにscale-ai(AIデータエンジニアリングアノテーションRLHF/data-labeling/7C3AED)/snorkel-ai(プログラマティックラベリング弱教師/data-labeling/0369A1)/activeloop(Deep LakeベクターテンソルDB/ai-data/FF4F00)の3社追加(876→879社)。sitemap 922 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
