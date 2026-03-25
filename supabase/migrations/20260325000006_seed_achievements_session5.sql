-- ============================================================
-- Seed: 2026-03-25 session5
-- ============================================================

insert into public.development_achievements (title, completed_at) values
  ('CORSエラー修正: 全Edge Function を --no-verify-jwt でデプロイ、OPTIONSプリフライトのJWT検証ブロックを解消', '2026-03-25 20:00:00+00'),
  ('CI/CD タグ重複エラー修正: git ls-remote でタグ存在チェック、連続プッシュでも重複エラーにならないよう改善', '2026-03-25 20:30:00+00'),
  ('新規ユーザー向けウェルカムカード追加: 登録7日以内ユーザーにモーニングブリーフィング/最初のメモ/Notionインポートへのクイックリンク表示', '2026-03-25 21:00:00+00'),
  ('技術ブログ投稿管理機能追加: Zenn/Qiita/はてなブログ/note/Medium/dev.to/Hashnode/Substack/GitHub Pages/NOTIONへの毎日投稿状況を管理・連続投稿ストリーク表示', '2026-03-25 21:30:00+00')
on conflict do nothing;
