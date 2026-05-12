-- PS#4 S325: 競合3社追加 846→849社 (sololearn/geeksforgeeks/zerotomastery)
-- SEO: "SoloLearn代替"/"GeeksforGeeks代替"/"Zero To Mastery代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S325: 競合3社追加 846→849社 (sololearn/geeksforgeeks/zerotomastery)',
  'comparison_page.dartにsololearn(コミュニティ駆動AI支援コーディング学習/learning/149EF2)/geeksforgeeks(CS面接準備DSAアルゴリズム/learning/2F8D46)/zerotomastery(エンジニア就職スキルアップ特化学習/learning/5D5DFF)の3社追加(846→849社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
