-- PS#4 S193: 競合3社追加 450→453社 (circle/podia/mighty-networks)
-- SEO: "Circle代替"/"Podia代替"/"Mighty Networks代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S193: 競合3社追加 450→453社 (circle/podia/mighty-networks)',
  'comparison_page.dartにcircle(オンラインコミュニティ/community/6B4FBB)/podia(クリエイターオールインワン/community/6EBD44)/mighty-networks(コミュニティ+コース/community/3B0764)の3社追加(450→453社)。sitemap 496 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
