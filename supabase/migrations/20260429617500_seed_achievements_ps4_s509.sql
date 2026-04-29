-- PS#4 S509: 競合3社追加 継続 (vault-hashicorp/crossplane/opentofu)
-- SEO: "HashiCorp Vault代替"/"Crossplane代替"/"OpenTofu代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S509: 競合3社追加 (vault-hashicorp/crossplane/opentofu)',
  'comparison_page.dartにvault-hashicorp(シークレット管理動的認証情報PKI暗号化/FFD814)/crossplane(K8sクラウドリソース管理Control PlaneマルチクラウドIaC CNCF/326CE5)/opentofu(Terraformオープンフォークライセンス変更後OSS完全互換CNCF/7B42BC)の3社追加。sitemap 1444 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
