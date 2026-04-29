-- PS#4 S520: 競合3社追加 継続 (knime/rapidminer/dbt)
-- SEO: "KNIME代替"/"RapidMiner代替"/"dbt代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S520: 競合3社追加 (knime/rapidminer/dbt)',
  'comparison_page.dartにknime(OSS データサイエンス・ビジュアルMLワークフロー・1000+ノード・企業向け無料/FFD700)/rapidminer(データサイエンスプラットフォーム・AutoML・コードレス・エンタープライズ・MLOps/E31837)/dbt(dbt Labs SQL-first・Git版管理・テスト・ドキュメント自動化・ELT変換/FF694A)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
