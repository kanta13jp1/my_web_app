-- PS#4 S163: 競合3社追加 360→363社 (clockwise/akiflow/classpass)
-- SEO: "Clockwise代替"/"Akiflow代替"/"ClassPass代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S163: 競合3社追加 360→363社 (clockwise/akiflow/classpass)',
  'comparison_page.dartにclockwise(AI集中時間確保/productivity/6C5CE7)/akiflow(タスク+カレンダー/productivity/FF4757)/classpass(フィットネスクラス予約/fitness/1DB7AC)の3社追加(360→363社)。sitemap 406 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
