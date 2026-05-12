-- PS#4 S142: 競合3社追加 297→300社 (day-one/toggl-track/rescuetime)
-- SEO: "Day One代替"/"Toggl Track代替"/"RescueTime代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S142: 競合3社追加 297→300社 (day-one/toggl-track/rescuetime)',
  'comparison_page.dartにday-one(プレミアムジャーナル日記/journaling/1A73E8)/toggl-track(時間追跡工数管理/time-tracking/E05EBB)/rescuetime(自動時間追跡集中力分析/time-tracking/2196F3)の3社追加(297→300社)。新カテゴリjournaling/time-tracking追加。sitemap 349 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
