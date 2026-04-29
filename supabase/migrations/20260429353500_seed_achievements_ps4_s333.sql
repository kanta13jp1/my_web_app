-- PS#4 S333: 競合3社追加 870→873社 (arize/datarobot/h2o-ai)
-- SEO: "Arize代替"/"DataRobot代替"/"H2O.ai代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S333: 競合3社追加 870→873社 (arize/datarobot/h2o-ai)',
  'comparison_page.dartにarize(MLオブザーバビリティAIモデルモニタリング/ml-monitoring/FF6900)/datarobot(エンタープライズAI AutoML/automl/005AE0)/h2o-ai(OSS AutoML責任あるAI/automl/FFD600)の3社追加(870→873社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
