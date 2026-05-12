-- PS#4 S330: 競合3社追加 861→864社 (mlflow/bentoml/ray-serve)
-- SEO: "MLflow代替"/"BentoML代替"/"Ray Serve代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S330: 競合3社追加 861→864社 (mlflow/bentoml/ray-serve)',
  'comparison_page.dartにmlflow(OSS ML実験追跡モデルレジストリDatabricks/mlops/0194E2)/bentoml(MLモデルサービングAI推論インフラOSS/mlops/FD5C63)/ray-serve(分散AIサービングスケーラブル推論/mlops/028CF7)の3社追加(861→864社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
