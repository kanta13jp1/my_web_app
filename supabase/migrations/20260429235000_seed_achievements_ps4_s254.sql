-- PS#4 S254: 競合3社追加 633→636社 (insomnia/cypress/k6)
-- SEO: "Insomnia代替"/"Cypress代替"/"k6代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S254: 競合3社追加 633→636社 (insomnia/cypress/k6)',
  'comparison_page.dartにinsomnia(REST/GraphQL/gRPC APIクライアント/dev/7400E0)/cypress(E2Eテストフレームワーク/dev/00BF88)/k6(ロードテストツール/dev/7D64FF)の3社追加(633→636社)。sitemap 637 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
