-- WEB版 2026-07-12: 自分API v1 実装 (Notion Developer Platform 対抗)
-- ユーザー単位 API キー発行 + ユーザー自作 Agent ツール (Worker) 登録・HMAC署名呼び出し
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '自分API v1 (Notion Developer Platform 対抗)',
  'ユーザーが自分のデータへ外部 AI エージェントからアクセスできる「自分API」を実装。API キー発行 (sha256ハッシュ保存・スコープ制・失効・有効期限)、外部公開エンドポイント (api.notes/tasks/achievements/workers)、ユーザー自作 Agent ツール (Worker) 登録と HMAC-SHA256 署名付き呼び出し、rate limit (60/分・2000/日)、SSRF ガード、監査ログ (90日保持) を tools-hub Edge Function に統合。',
  '2026-07-12'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '自分API v1 (Notion Developer Platform 対抗)'
);
