-- PS#4 S615: 競合3社追加 コンテナオーケストレーション (docker-swarm/rancher/openshift)
-- SEO: "Docker Swarm代替"/"Rancher代替"/"OpenShift代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S615: 競合3社追加 (docker-swarm/rancher/openshift)',
  'comparison_page.dartにdocker-swarm(Docker組み込みオーケストレーション・シンプル・YAMLベース・スモールクラスタ/2496ED)/rancher(マルチクラスタKubernetes管理・SUSE傘下・企業向け・Fleet・RKE2/0075A8)/openshift(エンタープライズK8s・CI/CD統合・IBM傘下・ハイブリッドクラウド/EE0000)の3社追加(1672社)。sitemap 1768 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
