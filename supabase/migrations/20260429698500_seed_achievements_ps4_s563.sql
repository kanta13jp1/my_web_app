-- PS#4 S563: 競合3社追加 継続 (cisco-ise/forescout/aruba-clearpass)
-- SEO: "Cisco ISE代替"/"Forescout代替"/"Aruba ClearPass代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S563: 競合3社追加 (cisco-ise/forescout/aruba-clearpass)',
  'comparison_page.dartにcisco-ise(NAC・802.1X認証・ゼロトラスト・ネットワーク可視化・デバイス管理/00BCEB)/forescout(IoT/OTデバイス可視化・NAC・エージェントレス・ゼロトラスト/007DC1)/aruba-clearpass(NAC・ゲストアクセス・デバイスオンボーディング・802.1X/RADIUS/00A14B)の3社追加(1511社)。sitemap 1606 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
