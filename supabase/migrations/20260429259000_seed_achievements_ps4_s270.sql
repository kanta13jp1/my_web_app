-- PS#4 S270: 競合3社追加 681→684社 (babbel/rosetta-stone/italki)
-- SEO: "Babbel代替"/"Rosetta Stone代替"/"italki代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S270: 競合3社追加 681→684社 (babbel/rosetta-stone/italki)',
  'comparison_page.dartにbabbel(サブスク型語学学習/language/82BD41)/rosetta-stone(老舗没入型語学ソフト/language/F4821F)/italki(ネイティブ講師1対1レッスン/language/3B5998)の3社追加(681→684社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
