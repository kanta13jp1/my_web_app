-- PS#5 S80: stale EF 29件削除 + site_guide_chat Supabase.instance.client try/catch fix
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'stale EF 29件削除 + site_guide_chat fix (PS#5 S80)',
  'stale EF: deploy-prod.yml 未記載 + Flutter invoke なし の 29 ディレクトリを一括削除 (access-control / ai-image-generator 等 / 最終変更=deno.land/std バルクアップグレードのみ)。除外: ai-writing-assistant (Win版#132 part 39 最近変更) / viral-video-ad-generator (feature work)。site_guide_chat_page.dart: addPostFrameCallback 内の Supabase.instance.client.auth.currentUser → try/catch で StateError 回避 (VM test 互換)。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
