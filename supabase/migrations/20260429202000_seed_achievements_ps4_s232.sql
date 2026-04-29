-- PS#4 S232: 競合3社追加 567→570社 (bitbucket/gitlab/gitea)
-- SEO: "Bitbucket代替"/"GitLab代替"/"Gitea代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S232: 競合3社追加 567→570社 (bitbucket/gitlab/gitea)',
  'comparison_page.dartにbitbucket(AtlassianGit/git/0052CC)/gitlab(DevSecOps統合/git/E24329)/gitea(セルフホスト軽量Git/git/609926)の3社追加(567→570社)。sitemap 616 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
