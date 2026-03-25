-- ============================================================
-- Seed: 2026-03-25 session6
-- ============================================================

insert into public.development_achievements (title, completed_at) values
  ('/morning-briefing と /note-editor の名前付きルートを追加: WelcomeNewUserCard のクイックアクションチップが正しくページ遷移するよう修正', '2026-03-25 22:00:00+00'),
  ('TechBlogTrackerPage に X Article プラットフォームを追加: X の長文記事機能への投稿管理に対応', '2026-03-25 22:30:00+00'),
  ('CI: growth-import-preview / growth-import-commit の未存在 Edge Function デプロイを削除、デプロイ安定化', '2026-03-25 23:00:00+00')
on conflict do nothing;
