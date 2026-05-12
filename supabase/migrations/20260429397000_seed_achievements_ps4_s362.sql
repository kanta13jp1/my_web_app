-- PS#4 S362: 競合3社追加 957→960社 (invision/zeplin/abstract)
-- SEO: "InVision代替"/"Zeplin代替"/"Abstract代替" 検索流入獲得
-- 🎉 sitemap 1003 vs-URLs 達成!

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S362: 競合3社追加 957→960社 (invision/zeplin/abstract)',
  'comparison_page.dartにinvision(プロトタイプデザインコラボフィードバック/design-tools/FF3366)/zeplin(デザインスペックハンドオフデザイナー開発者/design-tools/FFBD45)/abstract(デザインバージョン管理Sketchワークフロー/design-tools/191919)の3社追加(957→960社)。🎉 sitemap 1003 vs-URLs 突破。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
