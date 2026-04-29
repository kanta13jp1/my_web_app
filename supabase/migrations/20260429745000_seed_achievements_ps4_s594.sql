-- PS#4 S594: 競合3社追加 継続 (kubeflow/seldon/kserve)
-- SEO: "Kubeflow代替"/"Seldon代替"/"KServe代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S594: 競合3社追加 (kubeflow/seldon/kserve)',
  'comparison_page.dartにkubeflow(Kubernetes ML・パイプライン・モデルサービング・実験管理/326CE5)/seldon(MLモデルサービング・A/Bテスト・シャドウデプロイ・説明可能AI/7B2FBE)/kserve(標準化MLサービング・Knative・マルチモデル・自動スケーリング/00BCD4)の3社追加(1609社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
