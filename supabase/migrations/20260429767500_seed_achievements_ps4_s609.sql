-- PS#4 S609: 競合3社追加 継続 (gitlab-ci/bamboo/drone)
-- SEO: "GitLab CI/CD代替"/"Bamboo代替"/"Drone CI代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S609: 競合3社追加 (gitlab-ci/bamboo/drone)',
  'comparison_page.dartにgitlab-ci(統合DevOps・パイプライン・Docker/K8s・Auto DevOps/FC6D26)/bamboo(Atlassian CI/CD・Jira/Bitbucket統合・エンタープライズ/0052CC)/drone(コンテナネイティブCI/CD・YAML設定・セルフホスト・OSS/212121)の3社追加(1654社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
