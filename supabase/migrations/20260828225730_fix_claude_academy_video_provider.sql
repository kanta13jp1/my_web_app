-- AI大学: Claude Academy動画を正しいAnthropicプロバイダーへ関連付ける。

INSERT INTO ai_university_content (
  provider,
  category,
  title,
  content,
  source_url,
  published_at,
  sort_order,
  is_active
)
SELECT
  'anthropic',
  category,
  title,
  content,
  source_url,
  published_at,
  sort_order,
  true
FROM ai_university_content
WHERE provider = 'openai'
  AND category = 'video_claude_academy_overview'
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  source_url = EXCLUDED.source_url,
  published_at = EXCLUDED.published_at,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;

UPDATE ai_university_content
SET is_active = false
WHERE provider = 'openai'
  AND category = 'video_claude_academy_overview';
