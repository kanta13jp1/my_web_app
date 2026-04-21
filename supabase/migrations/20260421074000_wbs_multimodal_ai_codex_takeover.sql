-- Codex takeover: multimodal AI.
--
-- Only the task Codex actually started is moved to the Codex owner.
-- This slice adds image attachment support to the AI assistant chat page
-- and routes image+text prompts through ai-hub my_agent.chat.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 30),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done: Codex added AI assistant image attachment preview, sends imageBase64/mimeType to ai-hub my_agent.chat, and enabled Gemini inline image analysis with metadata-only history storage.',
    'Next: add PDF/audio multimodal inputs, conversation-level image persistence, provider fallback for vision models, and production usage/cost guardrails.'
  ),
  recovery_plan = CASE
    WHEN COALESCE(recovery_plan, '') = '' THEN
      'If Gemini image analysis is unavailable, keep text/voice chat working and surface the explicit ai-hub error while provider fallback for vision-capable models is added.'
    ELSE recovery_plan
  END,
  updated_at = now()
WHERE title = 'マルチモーダルAI'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Multimodal AI assistant image input',
  'Codex がマルチモーダルAIを一時引き継ぎ、AIアシスタントに画像添付プレビューを追加し、ai-hub my_agent.chat でGemini inline image解析を扱えるようにした。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
