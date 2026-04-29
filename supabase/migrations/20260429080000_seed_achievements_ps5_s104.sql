-- PS#5 S104: async safety bulk fix — mounted check 漏れ 24 pages
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S104: async safety bulk fix — mounted check 24 pages',
  'Python スクリプトで 47 pages スキャン → 24 pages に if (!mounted) return / if (mounted) setState 追加。catch/finally/try-success の 3 パターンを一括修正。setState after dispose バグを排除。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
