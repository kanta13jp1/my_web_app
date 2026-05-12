-- PS#4 S663: 競合3社追加 IaC/Kubernetes (cdk/helm/kustomize)
-- SEO: "AWS CDK代替"/"Helm代替"/"Kustomize代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S663: 競合3社追加 (cdk/helm/kustomize)',
  'comparison_page.dartにcdk(AWS CDK・クラウド開発キット・TypeScript/Python でインフラ定義/FF9900)/helm(Kubernetes パッケージマネージャー・チャート・テンプレート・バージョン管理/0F1689)/kustomize(Kubernetes設定カスタマイズ・オーバーレイ・テンプレートなし/326CE5)の3社追加(1816社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
