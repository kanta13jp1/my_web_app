-- PS#3 S121: AI大学 336→338社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S121: Devin (Cognition AI) 追加 — 336→337社',
    'Devin (世界初自律AIソフトウェアエンジニア / Cognition AI / SWE-bench最高スコア / 完全自律コーディング / $500/月 / Slack統合 / サンドボックスVM) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S121: v0.dev (Vercel) 追加 — 337→338社',
    'v0.dev (Vercel製 / AI UI生成 / React+Tailwind / shadcn/ui / TypeScript / アクセシビリティ / ダークモード / $20/月 / Next.js最適化) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
