-- PS#4 S158: 競合3社追加 345→348社 (lose-it/cronometer/strong)
-- SEO: "Lose It代替"/"Cronometer代替"/"Strong代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S158: 競合3社追加 345→348社 (lose-it/cronometer/strong)',
  'comparison_page.dartにlose-it(AIカロリー栄養管理/fitness/00BCD4)/cronometer(マイクロ栄養素精密/fitness/FF9800)/strong(AI筋トレ記録/fitness/C62828)の3社追加(345→348社)。全ファイル348統一。sitemap 638 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
