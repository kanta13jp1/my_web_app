-- PS#5 Session 114: CI統合 stale-ef-check + phantom EF 検出
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'CI統合: phantom EF検出をstale-ef-completeness-checkに追加 (PS#5 S114)',
  'stale-ef-completeness-check.yml にcheck_ef_coverage.pyステップ追加。push/PR時にstale EF(DEAD_LIST参照)+phantom EF(deploy-prod.yml未登録invoke)を両方自動検出。EFカバレッジ監視がCI組み込みに昇格。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
