-- PS版#110 WBS進捗更新 (2026-04-18)
-- ai-hub provider.chat 23→25プロバイダー (huggingface/minimax追加)

UPDATE wbs_tasks
SET progress = 35,
    status = 'in_progress',
    description = '25/80社実装済 (huggingface/minimax追加) — APIキー設定後に本番稼働'
WHERE title = 'provider.chat 残65社段階実装 (Phase 4)';

-- Rule 17 WF health check PS#110
INSERT INTO wbs_tasks (
  category, category_icon, category_order, title, description,
  instance, status, progress, start_date, end_date, milestone_code, priority
) VALUES (
  '品質・安定性', '🛡️', 8,
  'Rule17 WF健全性チェック 2026-04-18 #2',
  'ai-hub 25プロバイダー達成 / flutter analyze 0エラー / deno lint clean / orphan 0件',
  'ps', 'completed', 100,
  '2026-04-18', '2026-04-18', 'alpha', 'medium'
) ON CONFLICT DO NOTHING;
