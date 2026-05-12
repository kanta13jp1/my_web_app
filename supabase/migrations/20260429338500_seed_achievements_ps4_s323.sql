-- PS#4 S323: 競合3社追加 840→843社 (codesignal/codewars/frontendmasters)
-- SEO: "CodeSignal代替"/"Codewars代替"/"Frontend Masters代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S323: 競合3社追加 840→843社 (codesignal/codewars/frontendmasters)',
  'comparison_page.dartにcodesignal(AI技術スキル評価コーディングテスト/learning/4C84FF)/codewars(Kata形式プログラミング練習道場/learning/B01313)/frontendmasters(エキスパートフロントエンド深堀コース/learning/C02D28)の3社追加(840→843社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
