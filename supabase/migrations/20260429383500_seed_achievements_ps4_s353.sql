-- PS#4 S353: 競合3社追加 930→933社 (artbreeder/magic-eraser/fotor)
-- SEO: "Artbreeder代替"/"Magic Eraser代替"/"Fotor代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S353: 競合3社追加 930→933社 (artbreeder/magic-eraser/fotor)',
  'comparison_page.dartにartbreeder(AI画像ブレンドキャラクターコラボアート/image-gen/059669)/magic-eraser(AI画像消去オブジェクト削除写真編集/image-tools/DB2777)/fotor(AI写真編集画像生成デザインAll-in-One/image-tools/0EA5E9)の3社追加(930→933社)。sitemap 976 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
