-- PS#4 S371: 競合3社追加 984→987社 (practice-panther/appointy/timely)
-- SEO: "PracticePanther代替"/"Appointy代替"/"Timely代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S371: 競合3社追加 984→987社 (practice-panther/appointy/timely)',
  'comparison_page.dartにpractice-panther(弁護士リーガルPMケース管理請求/legal/111827)/appointy(オンライン予約スケジュール管理/booking/009688)/timely(AI自動タイムトラッキング工数記録/time-tracking/5A67D8)の3社追加(984→987社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
