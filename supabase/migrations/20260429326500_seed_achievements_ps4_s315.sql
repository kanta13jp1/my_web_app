-- PS#4 S315: 競合3社追加 816→819社 (loomly/planhat/tooljet)
-- SEO: "Loomly代替"/"Planhat代替"/"ToolJet代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S315: 競合3社追加 816→819社 (loomly/planhat/tooljet)',
  'comparison_page.dartにloomly(コンテンツカレンダーSNS管理/social/4F46E5)/planhat(データ駆動CSプラットフォーム/cs/2563EB)/tooljet(OSS内部ツール構築ローコード/no-code/5A67D8)の3社追加(816→819社)。sitemap 868 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
