-- PS#4 S273: 競合3社追加 690→693社 (gong/moodle/canvas-lms)
-- SEO: "Gong代替"/"Moodle代替"/"Canvas LMS代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S273: 競合3社追加 690→693社 (gong/moodle/canvas-lms)',
  'comparison_page.dartにgong(会話インテリジェンスセールスAI/sales/5D2D91)/moodle(OSS LMS教育機関世界標準/education/F98012)/canvas-lms(Instructure製クラウドLMS/education/E66000)の3社追加(690→693社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
