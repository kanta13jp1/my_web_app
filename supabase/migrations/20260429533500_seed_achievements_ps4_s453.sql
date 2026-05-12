-- PS#4 S453: 競合3社追加 1180→1183社 (smartthings/ring/philips-hue)
-- SEO: "SmartThings代替"/"Ring代替"/"Philips Hue代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S453: 競合3社追加 1180→1183社 (smartthings/ring/philips-hue)',
  'comparison_page.dartにsmartthings(Samsung スマートホームハブMatter/Zigbee 200+ブランド/smart-home/1428A0)/ring(Amazon傘下スマートドアベルセキュリティカメラRing Protect/home-security/0077C8)/philips-hue(Signify スマート照明1600万色Matter Hue Bridge/smart-lighting/0062FF)の3社追加(1180→1183社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
