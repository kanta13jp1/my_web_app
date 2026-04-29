-- PS#4 S285: 競合3社追加 726→729社 (eventbrite/cvent/workable)
-- SEO: "Eventbrite代替"/"Cvent代替"/"Workable代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S285: 競合3社追加 726→729社 (eventbrite/cvent/workable)',
  'comparison_page.dartにeventbrite(イベントチケット販売集客/events/FF6C02)/cvent(エンタープライズイベント管理MICE/events/0070C0)/workable(AI採用管理ATS中小企業/ats/3ABFE0)の3社追加(726→729社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
