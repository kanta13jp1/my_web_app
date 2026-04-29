-- PS#4 S354: 競合3社追加 933→936社 (befunky/photopea/luminar-ai)
-- SEO: "BeFunky代替"/"Photopea代替"/"Luminar Neo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S354: 競合3社追加 933→936社 (befunky/photopea/luminar-ai)',
  'comparison_page.dartにbefunky(AI写真編集コラージュグラフィックデザイン/image-tools/E11D48)/photopea(ブラウザ版無料Photoshop代替PSD対応/image-tools/0F766E)/luminar-ai(AIクリエイティブ写真編集スカイリプレイス/image-tools/2563EB)の3社追加(933→936社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
