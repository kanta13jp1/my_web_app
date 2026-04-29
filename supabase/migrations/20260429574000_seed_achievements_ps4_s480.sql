-- PS#4 S480: 競合3社追加 1261→1264社 (aliexpress/temu/wish)
-- SEO: "AliExpress代替"/"Temu代替"/"Wish代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S480: 競合3社追加 1261→1264社 (aliexpress/temu/wish)',
  'comparison_page.dartにaliexpress(Alibaba傘下中国直送220+国バイヤー保護Choice配送/E62F2E)/temu(PDD超低価格ゲーミフィケーション直接メーカー無料返品/FB4F3B)/wish(モバイルファーストEC超低価格スマートフィードWishPost/1779F7)の3社追加(1261→1264社)。sitemap 1363 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
