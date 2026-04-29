-- PS#4 S211: 競合3社追加 504→507社 (hootsuite/buffer/sprout-social)
-- SEO: "Hootsuite代替"/"Buffer代替"/"Sprout Social代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S211: 競合3社追加 504→507社 (hootsuite/buffer/sprout-social)',
  'comparison_page.dartにhootsuite(ソーシャル一括管理/social/000000)/buffer(SNS予約投稿/social/2C4BFF)/sprout-social(エンタープライズSNS/social/59CB59)の3社追加(504→507社)。sitemap 553 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
