-- PS#4 S151: 競合3社追加 324→327社 (omnifocus/fantastical/workflowy)
-- SEO: "OmniFocus代替"/"Fantastical代替"/"WorkFlowy代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S151: 競合3社追加 324→327社 (omnifocus/fantastical/workflowy)',
  'comparison_page.dartにomnifocus(プロ向けGTDシステム/tasks/7B2D8B)/fantastical(AI搭載スマートカレンダー/calendar/E63946)/workflowy(無限アウトライナー/notes/4183C4)の3社追加(324→327社)。新カテゴリ:calendar。全ファイル330統一。sitemap 620 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
