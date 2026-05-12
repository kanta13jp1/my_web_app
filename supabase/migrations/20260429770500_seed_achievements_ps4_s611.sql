-- PS#4 S611: 競合3社追加 継続 (woodpecker/tekton/argo-workflows)
-- SEO: "Woodpecker CI代替"/"Tekton代替"/"Argo Workflows代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S611: 競合3社追加 (woodpecker/tekton/argo-workflows)',
  'comparison_page.dartにwoodpecker(OSS CI/CD・Drone CIフォーク・セルフホスト・軽量/C83C3C)/tekton(Kubernetesネイティブ CI/CD・クラウドネイティブ・Google製/326CE5)/argo-workflows(K8s ワークフロー・DAG・並列実行・GitOps/EF7B4D)の3社追加(1654社)。sitemap 1750 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
