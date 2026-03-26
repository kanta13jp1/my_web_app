-- Session 18: LP 競合比較リンクセクション + SEO 全13競合キーワード対応 + Zenn記事第3弾

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'LP: 全13競合比較リンクセクション追加',
    'LandingPage に _buildComparisonLinksSection() を追加。全13競合(/vs-notion〜/vs-jobcan)へのリンクChipを表示し内部SEOリンクを構築。移行ガイドセクション直後に配置',
    '2026-03-26'
  ),
  (
    'SEO: index.html 全13競合キーワード対応',
    'meta keywords に Animaworks代替/Claude Code代替/Codex代替/netkeiba代替/OpenClaw代替/Claude Cowork代替/ジョブカン代替/Chatwork代替/X代替 を追加。Twitter Card タイトルも更新',
    '2026-03-26'
  ),
  (
    'Zenn記事第3弾: Flutter Webで13競合比較SEOページを量産した話',
    'docs/zenn_comparison_seo_20260326.md 新規作成・published: true。ComparisonPageの実装・sitemap更新・内部リンク設計を解説',
    '2026-03-26'
  )
ON CONFLICT DO NOTHING;
