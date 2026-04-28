-- PS#4 S120: 競合3社追加 231→234社 (medium/basecamp/netlify)
-- SEO: "Medium代替"/"Basecamp代替"/"Netlify代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S120: 競合3社追加 231→234社 (medium/basecamp/netlify)',
  'comparison_page.dartにmedium(ブログ・記事プラットフォーム/newsletter/000000)/basecamp(チームPM/project/1D2D35)/netlify(フロントエンドホスティング/hosting/00C7B7)の3社追加。competitorMeta/sitemap/_categoryOf更新。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
