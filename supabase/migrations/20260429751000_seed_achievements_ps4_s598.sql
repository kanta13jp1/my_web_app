-- PS#4 S598: 競合3社追加 継続 (elasticsearch-vector/turbopuffer/deeplake)
-- SEO: "Elasticsearch Vector代替"/"Turbopuffer代替"/"Deep Lake代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S598: 競合3社追加 (elasticsearch-vector/turbopuffer/deeplake)',
  'comparison_page.dartにelasticsearch-vector(ベクター検索・kNN・ハイブリッド・Elastic Stack/F04E98)/turbopuffer(サーバーレスベクターDB・低コスト・メタデータフィルタ/00C8FF)/deeplake(AI向けデータレイク・マルチモーダル・PyTorch/TF統合/0D47A1)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
