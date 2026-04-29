-- PS#4 S231: 競合3社追加 564→567社 (circleci/travis-ci/jenkins)
-- SEO: "CircleCI代替"/"Travis CI代替"/"Jenkins代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S231: 競合3社追加 564→567社 (circleci/travis-ci/jenkins)',
  'comparison_page.dartにcircleci(クラウドCI/CD/cicd/343434)/travis-ci(OSS CI/CD/cicd/3EAAAF)/jenkins(OSSセルフホストCI/cicd/D33833)の3社追加(564→567社)。sitemap 616 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
