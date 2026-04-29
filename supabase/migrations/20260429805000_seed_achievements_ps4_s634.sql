-- PS#4 S634: 競合3社追加 UIテスト/ビジュアルテスト (storybook/chromatic/percy)
-- SEO: "Storybook代替"/"Chromatic代替"/"Percy代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S634: 競合3社追加 (storybook/chromatic/percy)',
  'comparison_page.dartにstorybook(UIコンポーネント開発・ビジュアルテスト・ドキュメント自動生成/FF4785)/chromatic(ビジュアルリグレッション・Storybook連携・UI変更レビュー/FC521F)/percy(ビジュアルテスト・BrowserStack傘下・スクリーンショット比較/512DA8)の3社追加(1726社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
