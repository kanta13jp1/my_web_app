-- PS#4 S150: 競合3社追加 321→324社 (craft/things3/readwise)
-- SEO: "Craft代替"/"Things3代替"/"Readwise代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S150: 競合3社追加 321→324社 (craft/things3/readwise)',
  'comparison_page.dartにcraft(Apple Design Award受賞プレミアムノート/notes/0A73E8)/things3(Apple最高GTDタスク管理/tasks/2778E9)/readwise(Kindleハイライト間隔反復/reading/FF6B35)の3社追加(321→324社)。新カテゴリ:reading。全ファイル330統一。sitemap 620 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
