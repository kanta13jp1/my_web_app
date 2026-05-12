-- PS#4 S523: 競合3社追加 継続 (evidence/preset/snowplow)
-- SEO: "Evidence代替"/"Preset代替"/"Snowplow代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S523: 競合3社追加 (evidence/preset/snowplow)',
  'comparison_page.dartにevidence(コードファーストBI・Markdownレポート・SQL+Svelte・静的サイト生成・Git-first/2ECC71)/preset(Apache SupersetマネージドSaaS・OSS BIクラウド版・50+チャート・SQLLab/20A7C9)/snowplow(OSS行動データプラットフォーム・高品質イベント・DWH直送・GDPR/00ADEF)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
