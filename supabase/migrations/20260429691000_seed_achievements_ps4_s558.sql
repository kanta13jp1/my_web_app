-- PS#4 S558: 競合3社追加 継続 (fortinet/check-point/zscaler)
-- SEO: "Fortinet代替"/"Check Point代替"/"Zscaler代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S558: 競合3社追加 (fortinet/check-point/zscaler)',
  'comparison_page.dartにfortinet(FortiGate NGFW・SD-WAN・ZTNA・SASE・Security Fabric/EE3124)/check-point(Quantum NGFW・Infinity・脅威インテリジェンス・ゼロデイ防御/003087)/zscaler(ZIA/ZPA・SASE・SSE・ゼロトラスト・クラウドネイティブ/009BDE)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
