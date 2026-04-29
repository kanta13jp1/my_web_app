-- PS#4 S428: 競合3社追加 1108→1111社 (gojek/rappi/wolt)
-- SEO: "Gojek代替"/"Rappi代替"/"Wolt代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S428: 競合3社追加 1108→1111社 (gojek/rappi/wolt)',
  'comparison_page.dartにgojek(インドネシアスーパーアプリGoRide/GoCar/GoFood/GoPay/GoMart/GoMed/superapp/00880A)/rappi(ラテンアメリカスーパーアプリ食事食料品RappiPay金融/superapp/FF441F)/wolt(北欧欧州フードデリバリーDoorDash傘下Wolt Drive/food-delivery/009DE0)の3社追加(1108→1111社)。sitemap 1201 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
