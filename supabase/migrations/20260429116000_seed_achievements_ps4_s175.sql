-- PS#4 S175: 競合3社追加 396→399社 (lark/coda/slab)
-- SEO: "Lark代替"/"Coda代替"/"Slab代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S175: 競合3社追加 396→399社 (lark/coda/slab)',
  'comparison_page.dartにlark(ByteDance業務/collaboration/1456F0)/coda(DB+Doc融合/productivity/FF4F00)/slab(チームWiki/knowledge/1A56DB)の3社追加(396→399社)。sitemap 442 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
