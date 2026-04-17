-- WBS 進捗更新 (Windows版#74 完了反映 2026-04-17)
-- AI大学 78社 / provider.chat 13社対応 / Rule 10/11/14 健全性

-- AI大学 78社コンテンツ完全化: 85% → 90% (SambaNova追加で 77→78社達成)
UPDATE wbs_tasks
SET progress = 90,
    description = '全78社overview/models/api整備完了・残 quiz/fallback 充実化'
WHERE title = 'AI大学 78社コンテンツ完全化';

-- AIプロバイダー一覧・チャット機能: 100% 維持 (テスト呼び出しボタン拡張)
UPDATE wbs_tasks
SET description = '78社ステータス一覧+13社テスト呼び出しボタン完成 (Windows#74追加)'
WHERE title = 'AIプロバイダー一覧・チャット機能';

-- ai-hub provider.chat 全対応: 20% → 22% (OpenAI互換8+Mistral/Perplexity/Cohere+Anthropic/Gemini = 13/78社)
UPDATE wbs_tasks
SET progress = 22,
    description = '13/78社実装 (OpenAI互換8+独自3+特殊認証2)・画像系Phase3・残65社はPhase4'
WHERE title = 'ai-hub provider.chat 全対応';

-- 新規タスク追加: Windows#74 今後計画 (Phase 3/4)
INSERT INTO wbs_tasks (category, category_icon, category_order, title, description, instance, status, progress, start_date, end_date, milestone_code, priority) VALUES
  ('AI統合', '🤖', 5, 'provider.chat 画像系3社対応 (Phase 3)', 'Stability/Runware/Replicate image.generate action実装', 'windows', 'pending', 0, '2026-04-20', '2026-05-31', 'alpha', 'medium'),
  ('AI統合', '🤖', 5, 'provider.chat 残65社段階実装 (Phase 4)', 'Hugging Face/Ollama等 残プロバイダー順次追加', 'windows', 'pending', 0, '2026-05-01', '2026-07-31', 'beta', 'low'),
  ('品質・安定性', '🛡️', 8, 'ElevenLabs→Web Speech fallback完成', 'voice.tts 402検知時の自動切替実装済', 'windows', 'completed', 100, '2026-04-17', '2026-04-17', 'alpha', 'medium')
ON CONFLICT DO NOTHING;
