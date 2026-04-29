-- PS#4 S408: 競合3社追加 1048→1051社 (15five/360learning/absorblms)
-- SEO: "15Five代替"/"360Learning代替"/"Absorb LMS代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S408: 競合3社追加 1048→1051社 (15five/360learning/absorblms)',
  'comparison_page.dartに15five(従業員エンゲージメントパフォーマンス管理OKR/performance-mgmt/6BA5FF)/360learning(コラボレイティブラーニングLMS企業内ナレッジ共有/lms/00D2FF)/absorblms(エンタープライズLMS外部研修eラーニング/lms/0054A6)の3社追加(1048→1051社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
