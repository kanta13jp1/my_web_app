-- PS#4 S297: 競合3社追加 762→765社 (lucidchart/draw-io/creately)
-- SEO: "Lucidchart代替"/"draw.io代替"/"Creately代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S297: 競合3社追加 762→765社 (lucidchart/draw-io/creately)',
  'comparison_page.dartにlucidchart(クラウドフローチャートダイアグラム組織図/diagram/E8A623)/draw-io(無料OSSダイアグラムVisio代替/diagram/DAA025)/creately(ビジュアルコラボプロジェクト管理/diagram/9B42F5)の3社追加(762→765社)。sitemap 814 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
