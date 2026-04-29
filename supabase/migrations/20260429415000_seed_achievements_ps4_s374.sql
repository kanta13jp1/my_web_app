-- PS#4 S374: 競合3社追加 993→996社 (cin7/katana/inflow-inventory)
-- SEO: "Cin7代替"/"Katana代替"/"inFlow代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S374: 競合3社追加 993→996社 (cin7/katana/inflow-inventory)',
  'comparison_page.dartにcin7(クラウド在庫管理受発注倉庫EC連携/inventory/0099FF)/katana(製造業向けMRP製造オーダーBOM/mrp/7C3AED)/inflow-inventory(中小企業オフラインクラウド在庫バーコード/inventory/2563EB)の3社追加(993→996社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
