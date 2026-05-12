-- PS#4 S313: 競合3社追加 810→813社 (storyblok/dato-cms/kustomer)
-- SEO: "Storyblok代替"/"DatoCMS代替"/"Kustomer代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S313: 競合3社追加 810→813社 (storyblok/dato-cms/kustomer)',
  'comparison_page.dartにstoryblok(ヘッドレスCMSビジュアルエディター/cms/00B3A0)/dato-cms(APIファーストヘッドレスCMS GraphQL/cms/FF793F)/kustomer(AIファーストオムニチャネルCRMサービス/support/5B2D8E)の3社追加(810→813社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
