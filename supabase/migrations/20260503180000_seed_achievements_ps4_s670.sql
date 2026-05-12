-- PS#4 S670: 競合9社追加 フロントエンドビジュアルリグレッションテスト (Applitools/Happo/LostPixel/ArgosCi/BackstopJS/reg-suit/Screener/Diffy/VRT)
-- #1761 フロントエンドビジュアルテスト9社追加: visual-regressionカテゴリ新設

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S670: 競合9社追加 (Applitools/Happo/LostPixel/ArgosCI/BackstopJS/reg-suit/Screener/Diffy/VRT)',
  'comparison_page.dartにApplitools(AI Visual Testing/Eyes SDK/Ultrafast Grid/00BCD4)/Happo(クロスブラウザ視覚リグレッション/コンポーネントSS/7B1FA2)/Lost Pixel(OSSビジュアルリグレッション/Storybook対応/自己ホスト/43A047)/Argos CI(OSSビジュアルテストCI/GitHub Actions/FF7043)/BackstopJS(OSS CSS視覚リグレッション/Puppeteer/Playwright/1565C0)/reg-suit(OSSビジュアルリグレッション/S3/GCS対応/00897B)/Screener(Sauce Labs AI視覚テスト/クロスブラウザ/E53935)/Diffy(API/UIビジュアルリグレッション/本番ステージング差分/5C6BC0)/Visual Regression Tracker(OSSセルフホスト/マルチ言語SDK/チーム承認/6D4C41)の9社追加(1852→1861社)。sitemap 1948→1957 URLs。visual-regressionカテゴリ新設。',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
