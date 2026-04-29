-- PS#4 S627: 競合3社追加 コード品質/リンティング (eslint/prettier/husky)
-- SEO: "ESLint代替"/"Prettier代替"/"Husky代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S627: 競合3社追加 (eslint/prettier/husky)',
  'comparison_page.dartにeslint(JS/TS静的解析・カスタムルール・プラグイン・自動修正・VSCode統合/4B32C3)/prettier(コードフォーマット・意見あり・JS/TS/CSS/HTML・エディタ統合/F7B93E)/husky(Gitフック管理・pre-commit/commit-msg/push・lint-staged統合/000000)の3社追加(1708社)。sitemap 1804 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
