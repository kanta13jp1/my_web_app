-- PS#4 S91: sitemap vs-* 全174社 lastmod 2026-04-28 統一
-- S87-S90 で OGP/canonical/JSON-LD/seo-shell を全ページに追加したため
-- クロール再指示目的で lastmod を最新日付に更新

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S91: sitemap vs-*174社 lastmod統一 + SEO全施策完結確認',
  'vs-*全174社のsitemap lastmodを2026-04-28に統一(旧:2026-03-27/2026-04-27混在)。S87-S90でOGP/canonical/JSON-LD/seo-shell全追加済みのためGooglebotへ再クロール指示。/competitors Flutter pageがSupabase DB動的ロード(~190社)の設計確認。PS#4 SEO全施策完結。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
