-- PS#4 S192: 競合3社追加 447→450社 (patreon/ko-fi/buy-me-a-coffee)
-- SEO: "Patreon代替"/"Ko-fi代替"/"Buy Me a Coffee代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S192: 競合3社追加 447→450社 (patreon/ko-fi/buy-me-a-coffee)',
  'comparison_page.dartにpatreon(メンバーシップ/creator/FF424D)/ko-fi(投げ銭無料/creator/FF5E5B)/buy-me-a-coffee(シンプル支援/creator/FFDD00)の3社追加(447→450社)。sitemap 493 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
