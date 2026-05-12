-- PS#4 S206: 競合3社追加 489→492社 (freshsales/close/attio)
-- SEO: "Freshsales代替"/"Close CRM代替"/"Attio代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S206: 競合3社追加 489→492社 (freshsales/close/attio)',
  'comparison_page.dartにfreshsales(AI搭載CRM/crm/1DAE5F)/close(アウトバウンドCRM/crm/FD5750)/attio(次世代AI CRM/crm/3D3D3D)の3社追加(489→492社)。sitemap 535 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
