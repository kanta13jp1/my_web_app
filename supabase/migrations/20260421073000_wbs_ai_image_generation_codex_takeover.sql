-- Codex takeover: AI image generation integration.
--
-- Only the task Codex actually started is moved to the Codex owner.
-- This slice connects the Flutter AI image UI to the deployed media-hub
-- image.generate/image.list actions and improves OpenAI image error handling.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 35),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done: Codex switched /ai-image-generator from the legacy ai-image-generator EF to deployed media-hub image.generate/image.list, added size/style controls, gallery parsing for hub_data metadata, and hardened OpenAI image error responses.',
    'Next: persist generated assets into Supabase Storage, add provider fallback/usage quotas, and validate production OPENAI_API_KEY cost guardrails.'
  ),
  recovery_plan = CASE
    WHEN COALESCE(recovery_plan, '') = '' THEN
      'If OpenAI image generation is unavailable, keep media-hub returning explicit 503/502 errors and show the existing gallery while provider fallback or storage persistence is added.'
    ELSE recovery_plan
  END,
  updated_at = now()
WHERE title = '画像生成統合'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI image generation media-hub integration',
  'Codex が 画像生成統合 を一時引き継ぎ、/ai-image-generator 画面を deploy 対象の media-hub image.generate/image.list に接続。サイズ・スタイル選択、hub_data metadata 形式のギャラリー表示、OpenAI 画像生成エラーの明示返却を追加した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
