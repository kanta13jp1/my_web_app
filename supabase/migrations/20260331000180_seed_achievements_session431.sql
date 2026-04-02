-- Session 431: email-service + social-feed + document-collaboration + leave-management + knowledge-base
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Email Service Edge Function 追加', 'メール送信・テンプレート管理。Resend API統合/4組込テンプレート/送信履歴', '2026-03-31'),
  ('Social Feed Edge Function 追加', 'ソーシャルフィード。投稿/いいね/フォロー/タイムライン/ハッシュタグ', '2026-03-31'),
  ('Document Collaboration Edge Function 追加', 'ドキュメント共同編集。共有/権限管理/バージョン履歴/コメント', '2026-03-31'),
  ('Leave Management Edge Function 追加', '休暇管理。有給/病欠/特別休暇の申請/承認/残日数管理', '2026-03-31'),
  ('Knowledge Base Edge Function 追加', 'ナレッジベース。カテゴリ別記事/FAQ/検索/閲覧数/フィードバック', '2026-03-31')
ON CONFLICT DO NOTHING;
