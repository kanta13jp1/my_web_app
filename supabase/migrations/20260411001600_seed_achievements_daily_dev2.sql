-- Session daily-dev#2: マイスキル管理・ブログ投稿・EF Tier入れ替え・LP 60のこと
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Qiita/dev.to ブログ自動投稿 (T-1 第2弾)', 'note-comments記事をblog-auto-publisher EFでQiita・dev.toに自動投稿。フロントマター除去ヘルパーを追加してdev.to Date parseエラーを修正。', '2026-04-11'),
  ('マイスキル管理 UI 追加 (Slack対抗)', 'ai-assistant EFのsave_skill/list_skills/run_skill/delete_skillをFlutter UIで操作可能に。スキル一覧・作成・実行・削除ダイアログを実装。', '2026-04-11'),
  ('personal-dashboard EF Tier1昇格', 'audio-effects-processor Tier2降格とのSwapでpersonal-dashboard EFをSupabase Tier1にデプロイ。', '2026-04-11'),
  ('LP 60のこと達成', 'マイスキル機能をLPに追加し59→60のことに更新。', '2026-04-11')
ON CONFLICT DO NOTHING;
