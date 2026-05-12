-- PS#4 S504: 競合3社追加 1332→1341社 (sonarcloud/codeclimate/deepsource)
-- SEO: "SonarCloud代替"/"Code Climate代替"/"DeepSource代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S504: 競合3社追加 1332→1341社 (sonarcloud/codeclimate/deepsource)',
  'comparison_page.dartにsonarcloud(クラウド静的解析15言語CI/CD統合技術的負債/4E9BCD)/codeclimate(コード品質テストカバレッジVelocity生産性/48A860)/deepsource(AI静的解析自動コード修正25言語/6200EA)の3社追加(1332→1341社)。sitemap 1435 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
