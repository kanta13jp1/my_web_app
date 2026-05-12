-- PS#4 S451: 競合3社追加 1174→1177社 (wiz/onetrust/opensea)
-- SEO: "Wiz代替"/"OneTrust代替"/"OpenSea代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S451: 競合3社追加 1174→1177社 (wiz/onetrust/opensea)',
  'comparison_page.dartにwiz(クラウドセキュリティCNAPP CSPMエージェントレス脆弱性優先/cloud-security/3B82F6)/onetrust(GDPR/CCPA同意管理データプライバシープログラム/privacy-mgmt/00875A)/opensea(最大NFTマーケットプレイスEthereum/Polygon/nft/2081E2)の3社追加(1174→1177社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
