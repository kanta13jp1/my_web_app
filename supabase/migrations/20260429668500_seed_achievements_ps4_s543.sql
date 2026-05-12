-- PS#4 S543: 競合3社追加 1449→1458社 (github-codespaces/stackblitz/glitch)
-- SEO: "GitHub Codespaces代替"/"StackBlitz代替"/"Glitch代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S543: 競合3社追加 1449→1458社 (github-codespaces/stackblitz/glitch)',
  'comparison_page.dartにgithub-codespaces(GitHubクラウド開発環境・ブラウザVSCode・dev container・60時間無料/24292F)/stackblitz(ブラウザNode.js・WebContainers・即時起動・npm完全対応・ゼロインストール/1389FD)/glitch(コミュニティコーディング・即時公開・リミックス・Node.js・学習者向け/3333FF)の3社追加(1449→1458社)。sitemap 1552 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
