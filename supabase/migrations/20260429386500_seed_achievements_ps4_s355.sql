-- PS#4 S355: 競合3社追加 936→939社 (topaz-labs/facetune/vsco)
-- SEO: "Topaz Labs代替"/"Facetune代替"/"VSCO代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S355: 競合3社追加 936→939社 (topaz-labs/facetune/vsco)',
  'comparison_page.dartにtopaz-labs(AIアップスケール解像度向上ノイズ除去/image-tools/7C3AED)/facetune(AIポートレート美顔加工自撮り強化/image-tools/6366F1)/vsco(フォトグラファー向けAIフィルターコミュニティ/photo-app/1C1C1C)の3社追加(936→939社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
