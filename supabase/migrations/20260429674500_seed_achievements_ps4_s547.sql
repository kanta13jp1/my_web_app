-- PS#4 S547: 競合3社追加 継続 (checkov/trivy/falco)
-- SEO: "Checkov代替"/"Trivy代替"/"Falco代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S547: 競合3社追加 (checkov/trivy/falco)',
  'comparison_page.dartにcheckov(OSS IaCスキャン・Terraform/K8s/Helm・500+ポリシー・CI統合・自動修正/0070FF)/trivy(包括的脆弱性スキャン・コンテナ/IaC/SBOM・Kubernetes・最速・OSS/00B4D8)/falco(CNCFランタイムセキュリティ・Kubernetes脅威検知・eBPF・OSS/009BDE)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
