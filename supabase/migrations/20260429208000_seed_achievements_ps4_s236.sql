-- PS#4 S236: 競合3社追加 579→582社 (istio/vault/consul)
-- SEO: "Istio代替"/"HashiCorp Vault代替"/"Consul代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S236: 競合3社追加 579→582社 (istio/vault/consul)',
  'comparison_page.dartにistio(サービスメッシュ/service-mesh/466BB0)/vault(シークレット管理/security/000000)/consul(サービスディスカバリ/service-mesh/CA2171)の3社追加(579→582社)。sitemap 625 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
