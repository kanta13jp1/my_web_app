-- PS#4 S88: vs-*ページ JSON-LD BreadcrumbList structured data追加
-- 全174社の /vs-{slug} ページで WebPage + BreadcrumbList JSON-LD を動的生成
-- Googleリッチスニペット対応でvs-*ページのSEO品質をさらに強化

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S88: vs-*全174社ページJSON-LD structured data追加',
  'index.html の vsMatch ブロックに WebPage + BreadcrumbList JSON-LD を動的生成するコードを追加。全174社の /vs-{slug} ページでGoogleリッチスニペット(パンくずリスト)が表示可能になりSEO品質が向上。S87のOGP完結に続く追加SEO施策。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
