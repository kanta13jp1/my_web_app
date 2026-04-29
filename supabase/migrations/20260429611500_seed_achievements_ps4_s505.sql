-- PS#4 S505: 競合3社追加 継続 (codecov/coveralls/veracode)
-- SEO: "Codecov代替"/"Coveralls代替"/"Veracode代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S505: 競合3社追加 (codecov/coveralls/veracode)',
  'comparison_page.dartにcodecov(テストカバレッジCI/CD統合PR差分Sentry傘下/F05025)/coveralls(テストカバレッジGitHub/GitLab統合BadgePR差分/00BFA5)/veracode(SAST/DAST/SCA/IAST統合エンタープライズAST/1A237E)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
