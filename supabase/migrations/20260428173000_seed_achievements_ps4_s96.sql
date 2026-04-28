-- PS#4 S96: vs-*全174社ページにFAQPage JSON-LDリッチリスト追加
-- Google検索結果でFAQアコーディオン表示 → CTR改善狙い

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S96: vs-*全174社ページにFAQPage JSON-LD追加',
  'web/index.html vsMatchブロックにFAQPage JSON-LD自動注入を追加。3つのQ&A(競合との違い/完全無料か/乗り換え方法)をschema.orgで構造化。Google検索FAQリッチリザルト対象化→CTR改善。WebPage+BreadcrumbListに続く第2JSON-LDとして注入。全174社ページに一括適用。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
