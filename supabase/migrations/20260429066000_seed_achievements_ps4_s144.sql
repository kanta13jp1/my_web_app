-- PS#4 S144: 競合3社追加 303→306社 (habitica/noom/strava)
-- SEO: "Habitica代替"/"Noom代替"/"Strava代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S144: 競合3社追加 303→306社 (habitica/noom/strava)',
  'comparison_page.dartにhabitica(RPGゲーミフィケーション習慣管理/habit/7F4EAD)/noom(行動変容体重管理コーチング/wellness/6DB33F)/strava(ランニングフィットネス追跡/fitness/FC4C02)の3社追加(303→306社)。新カテゴリhabit/wellness/fitness追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
