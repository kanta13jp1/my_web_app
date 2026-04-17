-- PS版#111 WBS進捗更新 (2026-04-18)
-- ai-hub provider.chat 25→27プロバイダー (reka/writer追加)

UPDATE wbs_tasks
SET progress = 40,
    status = 'in_progress',
    description = '27/80社実装済 (reka/writer追加) — APIキー設定後に本番稼働'
WHERE title = 'provider.chat 残65社段階実装 (Phase 4)';

-- Rule 17 WF health check PS#111
INSERT INTO wbs_tasks (
  category, category_icon, category_order, title, description,
  instance, status, progress, start_date, end_date, milestone_code, priority
) VALUES (
  '品質・安定性', '🛡️', 8,
  'Rule17 WF健全性チェック 2026-04-18 #3',
  'ai-hub 27プロバイダー / ai-university-update GH006 continue-on-error修正 / 地方選new-kokumin追加',
  'ps', 'completed', 100,
  '2026-04-18', '2026-04-18', 'alpha', 'medium'
) ON CONFLICT DO NOTHING;
