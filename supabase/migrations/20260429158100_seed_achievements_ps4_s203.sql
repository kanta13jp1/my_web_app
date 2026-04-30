-- PS#4 S203: 競合3社追加 480→483社 (cloud-sign/adobe-sign/signnow)
-- SEO: "クラウドサイン代替"/"Adobe Sign代替"/"SignNow代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S203: 競合3社追加 480→483社 (cloud-sign/adobe-sign/signnow)',
  'comparison_page.dartにcloud-sign(日本発電子署名/esign/003C7E)/adobe-sign(AdobePDF署名/esign/FF0000)/signnow(airSlate署名/esign/00A651)の3社追加(480→483社)。sitemap 526 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
