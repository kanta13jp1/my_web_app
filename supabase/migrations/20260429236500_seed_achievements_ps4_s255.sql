-- PS#4 S255: 競合3社追加 636→639社 (codesandbox/gitpod/mintlify)
-- SEO: "CodeSandbox代替"/"Gitpod代替"/"Mintlify代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S255: 競合3社追加 636→639社 (codesandbox/gitpod/mintlify)',
  'comparison_page.dartにcodesandbox(ブラウザ完結クラウドIDE/cloud-ide/151515)/gitpod(Gitから即時開発環境/cloud-ide/FF8A00)/mintlify(AIドキュメントプラットフォーム/docs/00C4A0)の3社追加(636→639社)。sitemap 646 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
