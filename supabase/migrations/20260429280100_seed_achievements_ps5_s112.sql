-- PS#5 Session 112: phantom EF calls → growth-hub migration
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'phantom EF calls 4件 → growth-hub移行 (PS#5 S112)',
  'growth-command-center/growth-import-preview/growth-import-commit/growth-share-signal の4件を growth-hub action (command.analyze/import.preview/import.commit/share.track) に移行。デプロイされていない phantom EF呼び出しを0に。EF数 85+→19達成でef_count cross-instance-pr done/移動。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
