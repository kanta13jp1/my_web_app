-- PS#3 S120: AI大学 334→336社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S120: Windsurf (Codeium AI IDE) 追加 — 334→335社',
    'Windsurf (Codeium製AI IDE / VS Code fork / Cascade Agent / 無料プラン手厚い / Cursor対抗) を AI大学コンテンツとして追加。月$15 Pro プランで Cascade Agent 無制限。WebContainers不使用でローカル実行。',
    '2026-04-29'
  ),
  (
    'AI大学 S120: Bolt.new (StackBlitz) 追加 — 335→336社',
    'Bolt.new (StackBlitz製 / WebContainers / ブラウザ完結フルスタック開発 / Claude 3.5 Sonnet / Replit Agent競合 / バイブコーディング火付け役) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
