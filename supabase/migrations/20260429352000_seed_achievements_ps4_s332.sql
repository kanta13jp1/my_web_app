-- PS#4 S332: 競合3社追加 867→870社 (great-expectations/evidently/whylabs)
-- SEO: "Great Expectations代替"/"Evidently代替"/"WhyLabs代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S332: 競合3社追加 867→870社 (great-expectations/evidently/whylabs)',
  'comparison_page.dartにgreat-expectations(データ品質検証テスト自動化/data-quality/FF6B35)/evidently(MLモデル評価モニタリングドリフト検出OSS/ml-monitoring/9B5DE5)/whylabs(AIオブザーバビリティMLモデル監視/ml-monitoring/2563EB)の3社追加(867→870社)。sitemap 913 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
