-- PS#4 S233: 競合3社追加 570→573社 (sonarqube/snyk/checkmarx)
-- SEO: "SonarQube代替"/"Snyk代替"/"Checkmarx代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S233: 競合3社追加 570→573社 (sonarqube/snyk/checkmarx)',
  'comparison_page.dartにsonarqube(コード品質解析/security/4E9BCD)/snyk(開発者セキュリティ/security/4C4ABE)/checkmarx(エンタープライズAST/security/6CD64A)の3社追加(570→573社)。sitemap 616 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
