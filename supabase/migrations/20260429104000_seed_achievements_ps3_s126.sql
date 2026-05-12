-- PS#3 S126: AI大学 346→348社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S126: Sweep AI 追加 — 346→347社',
    'Sweep AI (GitHub Issue→PR自動生成 / AIジュニアエンジニア / OSS 7k+ stars / GPT-4/Claude / Vector DB / 小〜中規模タスク特化 / $19/月 Pro / テスト自動追加) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S126: Grit.io 追加 — 347→348社',
    'Grit.io (コード移行・アップグレード自動化 / GritQL定義言語 / React/Vue/フレームワーク移行 / lodash→native / webpack→Vite / 10万行以上対応 / Shopify・Stripe採用 / $24/月 Pro) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
