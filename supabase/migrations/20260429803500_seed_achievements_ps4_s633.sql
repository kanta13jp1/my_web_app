-- PS#4 S633: 競合3社追加 テストフレームワーク (jest/vitest/selenium)
-- SEO: "Jest代替"/"Vitest代替"/"Selenium代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S633: 競合3社追加 (jest/vitest/selenium)',
  'comparison_page.dartにjest(JS/TSテスト・スナップショット・モック・カバレッジ・並行実行/C21325)/vitest(Vite統合・Jest互換API・ESM・高速・TypeScript/6E9F18)/selenium(ブラウザ自動化・E2Eテスト・多言語・WebDriver・Grid・クロスブラウザ/43B02A)の3社追加(1726社)。sitemap 1822 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
