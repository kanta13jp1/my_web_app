-- PS#4 S334: 競合3社追加 873→876社 (pycaret/optuna/labelstudio)
-- SEO: "PyCaret代替"/"Optuna代替"/"Label Studio代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S334: 競合3社追加 873→876社 (pycaret/optuna/labelstudio)',
  'comparison_page.dartにpycaret(ローコードPython ML AutoML/automl/3776AB)/optuna(ハイパーパラメータ最適化OSS/automl/00B4D8)/labelstudio(OSS データラベリングアノテーション/data-labeling/FF3D71)の3社追加(873→876社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
