-- Session 17: 全13競合 SEO 比較ページ完成
-- /vs-x / /vs-animaworks / /vs-claude-code / /vs-codex
-- /vs-netkeiba / /vs-openclaw / /vs-claude-cowork / /vs-jobcan

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '競合比較 SEO ページ全13社対応完了',
    'ComparisonPage に X/Animaworks/Claude Code/Codex/netkeiba/OpenClaw/Claude Cowork/ジョブカン の8社を追加。8ルートを main.dart に追加。sitemap.xml に8URL追加（合計21URL）。全13競合の検索キーワードから有機流入を獲得',
    '2026-03-26'
  )
ON CONFLICT DO NOTHING;
