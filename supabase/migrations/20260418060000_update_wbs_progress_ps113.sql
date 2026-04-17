-- PS版#113 WBS進捗更新 (2026-04-18)
-- ai-hub provider.chat 27→29プロバイダー (meta/nebius追加)

UPDATE wbs_tasks
SET progress = 45,
    status = 'in_progress',
    description = '29/80社実装済 (meta/nebius追加) — APIキー設定後に本番稼働'
WHERE title = 'provider.chat 残65社段階実装 (Phase 4)';

-- Rule 17 WF health check PS#113
INSERT INTO wbs_tasks (
  category, category_icon, category_order, title, description,
  instance, status, progress, start_date, end_date, milestone_code, priority
) VALUES (
  '品質・安定性', '🛡️', 8,
  'Rule17 WF健全性チェック 2026-04-18 #4',
  'CORS修正(fetch-local-politicians廃止EF) / migration衝突修正(040000→041000) / ai-hub 29プロバイダー',
  'ps', 'completed', 100,
  '2026-04-18', '2026-04-18', 'alpha', 'medium'
) ON CONFLICT DO NOTHING;
