-- Codex progress: reduce Flutter Web startup work before first frame.

UPDATE wbs_tasks
SET
  status = 'in_progress',
  progress = GREATEST(progress, 40),
  owner_instance = 'codex',
  updated_at = now()
WHERE title = 'Webパフォーマンス最適化 (LCP < 2.5s)';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Flutter Web startup optimization',
  'Webパフォーマンス最適化として、通知初期化と SharedPreferences 読み込みを first frame 後へ遅延し、Supabase / Flutter bootstrap の resource hints を追加。さらに認証後ホームのオンボーディング判定 Future をキャッシュし、再ビルド時の重複 Supabase 読み取りを抑制した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
