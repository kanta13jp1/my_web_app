-- PS#4 S591: 競合3社追加 継続 (google-bigquery/amazon-redshift/azure-synapse)
-- SEO: "BigQuery代替"/"Amazon Redshift代替"/"Azure Synapse代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S591: 競合3社追加 (google-bigquery/amazon-redshift/azure-synapse)',
  'comparison_page.dartにgoogle-bigquery(サーバーレスDWH・BQML・ペタバイト規模・SQL分析/4285F4)/amazon-redshift(クラウドDWH・列指向・RA3・Spectrum・AWS統合/FF4B00)/azure-synapse(統合分析・Spark・SQLプール・Power BI統合/0078D4)の3社追加(1600社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
