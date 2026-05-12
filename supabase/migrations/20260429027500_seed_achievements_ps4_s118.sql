-- PS#4 S118: 競合3社追加 225→228社 (n8n/buffer/hootsuite)
-- SEO: "n8n代替"/"Buffer代替"/"Hootsuite代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S118: 競合3社追加 225→228社 (n8n/buffer/hootsuite)',
  'comparison_page.dartにn8n(オープンソースワークフロー自動化/automation/EA4B71)/buffer(SNSスケジューリング/social-media/2C4BFF)/hootsuite(SNS統合管理/social-media/000000)の3社追加(225→228社)。新カテゴリautomation/social-media追加。competitorMeta/sitemap+3URL/_categoryOf更新。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
