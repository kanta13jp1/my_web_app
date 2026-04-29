-- PS#4 S298: 競合3社追加 765→768社 (refersion/shareasale/tapfiliate)
-- SEO: "Refersion代替"/"ShareASale代替"/"Tapfiliate代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S298: 競合3社追加 765→768社 (refersion/shareasale/tapfiliate)',
  'comparison_page.dartにrefersion(アフィリエイトインフルエンサー管理Shopify/affiliate/5D3EDB)/shareasale(Awin傘下中規模アフィリエイトネットワーク/affiliate/00AAED)/tapfiliate(SaaS向けアフィリエイト紹介プログラム/affiliate/00B3FF)の3社追加(765→768社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
