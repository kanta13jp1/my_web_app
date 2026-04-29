-- PS#4 S212: 競合3社追加 507→510社 (later/planoly/socialbee)
-- SEO: "Later代替"/"Planoly代替"/"SocialBee代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S212: 競合3社追加 507→510社 (later/planoly/socialbee)',
  'comparison_page.dartにlater(Instagramビジュアルプランナー/social/EE5D99)/planoly(Pinterest/Instagram管理/social/8673C0)/socialbee(コンテンツリサイクル/social/FFCD00)の3社追加(507→510社)。sitemap 553 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
