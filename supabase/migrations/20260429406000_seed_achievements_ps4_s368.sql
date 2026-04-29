-- PS#4 S368: 競合3社追加 975→978社 (when-i-work/homebase/7shifts)
-- SEO: "When I Work代替"/"Homebase代替"/"7shifts代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S368: 競合3社追加 975→978社 (when-i-work/homebase/7shifts)',
  'comparison_page.dartにwhen-i-work(中小企業シフトスケジュール出勤管理/workforce/1AA7EC)/homebase(小規模ビジネス無料HR採用給与/workforce/FF5454)/7shifts(レストラン従業員スケジュール売上予測/restaurant/EA5F1C)の3社追加(975→978社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
