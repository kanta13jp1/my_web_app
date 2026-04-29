-- PS#4 S252: 競合3社追加 627→630社 (warp-terminal/prismic/webiny)
-- SEO: "Warp Terminal代替"/"Prismic代替"/"Webiny代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S252: 競合3社追加 627→630社 (warp-terminal/prismic/webiny)',
  'comparison_page.dartにwarp-terminal(AI搭載次世代ターミナル/dev/01F2C0)/prismic(ヘッドレスCMS/cms/5163BA)/webiny(サーバーレスOSS CMS/cms/FA5A28)の3社追加(627→630社)。sitemap 637 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
