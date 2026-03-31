-- Session 432b (Web版): Edge Functions 115→120 (5本追加)
-- push-notification-manager, realtime-presence, voice-memo-transcriber, ocr-document-scanner, oauth-sso-provider

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Web Push通知管理', 'LINE/Discord/Slack競合のVAPID Web Push購読管理・対象指定Push配信・配信統計機能を実装', '2026-03-31'),
  ('リアルタイムプレゼンス', 'Notion/Google Docs競合のドキュメント閲覧者一覧・カーソル位置共有・編集ロック管理・オンラインステータス機能を実装', '2026-03-31'),
  ('音声メモ・文字起こし', 'Google Keep/LINE競合の音声メモ登録・文字起こし結果管理・AI要約・ノート変換機能を実装', '2026-03-31'),
  ('OCR文書スキャン', 'Evernote/MoneyForward競合のレシート→経費自動登録・名刺→連絡先登録・手書きメモデジタル化機能を実装', '2026-03-31'),
  ('SSO/OAuth管理', 'GitHub/Google/Microsoft/Slack競合のOAuth2.0/SAMLプロバイダー管理・エンタープライズSSO接続・ログイン履歴機能を実装', '2026-03-31')
ON CONFLICT DO NOTHING;
