-- PS#5 Session 115: memory-search-hub EF + effort_router/task_budget 本実装 (Codex#2 merge)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S115: memory-search-hub EF + effort_router/task_budget 本実装',
  'Codex#2 branch (2476ea3a2) を main に統合。memory-search-hub (BM25+vector hybrid search, memory.search/rank/related/stats), effort_router.ts stub→本実装(217L), task_budget.ts stub→本実装(308L), 3 migrations (memory_index/task_budget/effort_config), check_budget.py, sync_memory_index.py, memory-search-sync.yml, deploy-prod.yml +memory-search-hub (20/50 EF)',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
