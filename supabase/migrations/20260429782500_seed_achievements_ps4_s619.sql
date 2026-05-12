-- PS#4 S619: 競合3社追加 K8sネットワーキング (cilium/calico/envoy)
-- SEO: "Cilium代替"/"Calico代替"/"Envoy Proxy代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S619: 競合3社追加 (cilium/calico/envoy)',
  'comparison_page.dartにcilium(eBPFベースK8sネットワーク・セキュリティ・Hubble可観測性・CNCF/F8C517)/calico(K8sネットワークポリシー・BGP・ゼロトラスト・Tigera製/FC8100)/envoy(クラウドネイティブプロキシ・gRPC・可観測性・Lyft・CNCF/9B51E0)の3社追加(1681社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
