-- PS#4 S238: 競合3社追加 585→588社 (aws-cloudwatch/gcp-cloud-logging/azure-monitor)
-- SEO: "AWS CloudWatch代替"/"GCP Cloud Logging代替"/"Azure Monitor代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S238: 競合3社追加 585→588社 (aws-cloudwatch/gcp-cloud-logging/azure-monitor)',
  'comparison_page.dartにaws-cloudwatch(AWSネイティブ監視/cloud-monitoring/FF9900)/gcp-cloud-logging(GCPログ分析/cloud-monitoring/4285F4)/azure-monitor(Azureアプリ監視/cloud-monitoring/0078D4)の3社追加(585→588社)。sitemap 634 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
