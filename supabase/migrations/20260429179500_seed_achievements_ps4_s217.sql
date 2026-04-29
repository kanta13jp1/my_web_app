-- PS#4 S217: 競合3社追加 522→525社 (metabase/domo/qlik)
-- SEO: "Metabase代替"/"Domo代替"/"Qlik代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S217: 競合3社追加 522→525社 (metabase/domo/qlik)',
  'comparison_page.dartにmetabase(OSSセルフサービスBI/bi/509EE3)/domo(クラウドBI/bi/E01E5A)/qlik(アソシエイティブAI/bi/009845)の3社追加(522→525社)。sitemap 571 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
