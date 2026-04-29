-- PS#4 S665: 競合3社追加 k8s開発ツール/IaC (skaffold/tilt/terragrunt)
-- SEO: "Skaffold代替"/"Tilt代替"/"Terragrunt代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S665: 競合3社追加 (skaffold/tilt/terragrunt)',
  'comparison_page.dartにskaffold(Google製Kubernetes継続開発・ビルド/デプロイ自動化・ホットリロード/4285F4)/tilt(ローカルKubernetes開発・Starlark設定・ライブアップデート/20BA31)/terragrunt(Terraform薄いラッパー・DRY・モジュール管理/7B42BC)の3社追加(1816社)。sitemap 1912 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
