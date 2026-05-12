-- PS#4 S87: vs-* 全174社 個別OGPメタタグ追加 (index.html competitorMeta 153社拡張)
-- 旧来は21社のみ個別OGP、残153社はサイト共通メタにフォールバック
-- 全174社の /vs-* ページでSNSシェア時に会社名入りのtitle/descが表示される

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S87: vs-*ページ全174社OGPメタタグ完結 (index.html +153社)',
  'index.html の competitorMeta に S82-S86で追加した153社のOGP title/descを一括追加。旧来は21社のみ個別OGP対応だったが、全174社の /vs-* ページでSNSシェア・SEO時に会社名入りのタイトル・説明が表示されるようになった。PS#4 vs-*SEOページ整備の完全完結。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
