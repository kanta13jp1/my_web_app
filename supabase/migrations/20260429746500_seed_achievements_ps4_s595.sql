-- PS#4 S595: 競合3社追加 継続 (onnx/triton-inference/zenml)
-- SEO: "ONNX代替"/"Triton Inference Server代替"/"ZenML代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S595: 競合3社追加 (onnx/triton-inference/zenml)',
  'comparison_page.dartにonnx(オープンMLフォーマット・フレームワーク間移植・ランタイム最適化/005CED)/triton-inference(NVIDIA MLサービング・GPU最適化・動的バッチング・アンサンブル/76B900)/zenml(MLOpsフレームワーク・パイプライン抽象化・マルチスタック・再現性/6B4FBB)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
