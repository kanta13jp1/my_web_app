-- PS#4 S235: 競合3社追加 576→579社 (docker-hub/kubernetes/argocd)
-- SEO: "Docker Hub代替"/"Kubernetes代替"/"Argo CD代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S235: 競合3社追加 576→579社 (docker-hub/kubernetes/argocd)',
  'comparison_page.dartにdocker-hub(コンテナレジストリ/container/2496ED)/kubernetes(コンテナオーケストレーション/container/326CE5)/argocd(GitOps CD/gitops/EF7B4D)の3社追加(576→579社)。sitemap 625 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
