-- PS版#108 WBS進捗更新 (2026-04-18)
-- ai-hub provider.chat 20→23プロバイダー追加

-- CI修正完了 (trailing commas + const constructors)
UPDATE wbs_tasks
SET progress = 100,
    status = 'completed',
    description = 'flutter analyze 0エラー維持 — trailing commas/const修正完了 (PS版#108)'
WHERE title = 'flutter analyze 0エラー常時維持';

-- ai-hub Phase 4: 13→23プロバイダー (前回14→20, 今回20→23)
UPDATE wbs_tasks
SET progress = 30,
    status = 'in_progress',
    description = '23/80社実装済 (cerebras/nvidia/moonshot/ai21/01ai/zhipu/qwen/inflection/allenai追加) — APIキー設定後に本番稼働'
WHERE title = 'provider.chat 残65社段階実装 (Phase 4)';

-- Rule 17 WF health check
INSERT INTO wbs_tasks (
  category, category_icon, category_order, title, description,
  instance, status, progress, start_date, end_date, milestone_code, priority
) VALUES (
  '品質・安定性', '🛡️', 8,
  'Rule17 WF健全性チェック 2026-04-18',
  'deploy-prod CI lint修正完了 / orphan 0件 / cross-instance-prs 0件',
  'ps', 'completed', 100,
  '2026-04-18', '2026-04-18', 'alpha', 'medium'
) ON CONFLICT DO NOTHING;
