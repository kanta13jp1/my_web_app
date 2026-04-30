-- PS#5 S115: memory-search-hub EF plus effort and budget support

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S115: memory-search-hub EF plus effort and budget support',
  'Merged Codex#2 memory-search-hub work, including BM25/vector search actions, effort_router and task_budget support, migrations, sync tooling, and deploy workflow updates.',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
