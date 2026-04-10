-- Session Web#26: JWT署名検証修正 (セキュリティ バグ #B4)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'セキュリティ修正: note-comments JWT署名検証',
  'note-comments Edge Functionの`getUserIdFromJwt()`(署名未検証・base64 decodeのみ)を削除し、`client.auth.getUser()`による正式JWT署名検証に置き換え。偽造JWTによる任意ユーザーコメント操作の脆弱性(バグ#B4)を修正。deno lint 0エラー確認済み。',
  '2026-04-10'
)
ON CONFLICT DO NOTHING;
