-- PS#4 S477: 競合3社追加 1252→1255社 (tinder/ebay/etsy)
-- SEO: "Tinder代替"/"eBay代替"/"Etsy代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S477: 競合3社追加 1252→1255社 (tinder/ebay/etsy)',
  'comparison_page.dartにtinder(マッチングアプリ元祖スワイプSuper Like Boost 70+国/FF6B6B)/ebay(オークション固定価格EC180+国バイヤー保護/E53238)/etsy(ハンドメイドビンテージ96M+購入者Etsy Ads/F16521)の3社追加(1252→1255社)。sitemap 1354 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
