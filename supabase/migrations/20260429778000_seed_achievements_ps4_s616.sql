-- PS#4 S616: 競合3社追加 コンテナオーケストレーション (k3s/k0s/microk8s)
-- SEO: "K3s代替"/"k0s代替"/"MicroK8s代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S616: 競合3社追加 (k3s/k0s/microk8s)',
  'comparison_page.dartにk3s(軽量Kubernetes・エッジ/IoT/ARM・単一バイナリ・低リソース・Rancher Labs製/326CE5)/k0s(ゼロフリクションKubernetes・単一バイナリ・Mirantis製・エッジ/マルチクラウド/0D2137)/microk8s(Ubuntu/Canonical製K8s・snap・アドオン方式・開発/エッジ/CI向け/E95420)の3社追加(1672社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
