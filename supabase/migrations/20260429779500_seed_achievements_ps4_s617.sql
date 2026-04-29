-- PS#4 S617: 競合3社追加 マネージドKubernetes (eks/gke/aks)
-- SEO: "Amazon EKS代替"/"Google GKE代替"/"Azure AKS代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S617: 競合3社追加 (eks/gke/aks)',
  'comparison_page.dartにeks(マネージドKubernetes・AWS統合・Fargate・EKS Anywhere・エンタープライズ/FF9900)/gke(Google GKE・Autopilot・Anthos・GKE Enterprise・Google Cloud統合/4285F4)/aks(Azure K8s Service・KEDA・Workload Identity・Microsoft・ハイブリッド/0078D4)の3社追加(1672社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
