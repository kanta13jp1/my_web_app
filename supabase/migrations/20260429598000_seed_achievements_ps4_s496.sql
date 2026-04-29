-- PS#4 S496: 競合3社追加 継続 (salesmate/zendesk-sell/sugar-crm)
-- SEO: "Salesmate代替"/"Zendesk Sell代替"/"SugarCRM代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S496: 競合3社追加 (salesmate/zendesk-sell/sugar-crm)',
  'comparison_page.dartにsalesmate(Sandy AI通話SMS自動化パイプライン/1565C0)/zendesk-sell(Zendesk統合パイプラインメール通話追跡AIアシスタント/03363D)/sugar-crm(AI予測オンプレクラウドカスタマイズ自由エンタープライズ/E91E63)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
