-- PS#4 S204: 競合3社追加 483→486社 (jasper/wordtune/quillbot)
-- SEO: "Jasper代替"/"Wordtune代替"/"QuillBot代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S204: 競合3社追加 483→486社 (jasper/wordtune/quillbot)',
  'comparison_page.dartにjasper(AI長文コンテンツ/writing/FF6B00)/wordtune(AI文章リライト/writing/5D5CDD)/quillbot(AIパラフレーズ/writing/00B7A8)の3社追加(483→486社)。sitemap 535 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
