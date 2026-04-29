-- PS#4 S224: 競合3社追加 543→546社 (vercel/netlify/render)
-- SEO: "Vercel代替"/"Netlify代替"/"Render代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S224: 競合3社追加 543→546社 (vercel/netlify/render)',
  'comparison_page.dartにvercel(フロントエンドホスティング/hosting/000000)/netlify(Jamstackプラットフォーム/hosting/00AD9F)/render(フルスタッククラウド/hosting/46E3B7)の3社追加(543→546社)。sitemap 589 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
