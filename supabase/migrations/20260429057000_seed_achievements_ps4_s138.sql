-- PS#4 S138: 競合3社追加 285→288社 (photoshop/lightroom/adobe-illustrator)
-- SEO: "Photoshop代替"/"Lightroom代替"/"Illustrator代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S138: 競合3社追加 285→288社 (photoshop/lightroom/adobe-illustrator)',
  'comparison_page.dartにphotoshop(プロ画像編集・合成/design/31A8FF)/lightroom(RAW現像・写真管理/design/27AAE1)/adobe-illustrator(プロベクターグラフィック/design/FF9A00)の3社追加(285→288社)。sitemap337URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
