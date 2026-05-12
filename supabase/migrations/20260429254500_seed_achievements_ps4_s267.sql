-- PS#4 S267: 競合3社追加 672→675社 (rakuraku-seisan/talentpalette/techacademy)
-- SEO: "楽楽精算代替"/"タレントパレット代替"/"テックアカデミー代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S267: 競合3社追加 672→675社 (rakuraku-seisan/talentpalette/techacademy)',
  'comparison_page.dartにrakuraku-seisan(日本クラウド経費精算/hr-jp/0082CC)/talentpalette(日本人材データ活用HRアナリティクス/hr-jp/008000)/techacademy(日本最大規模オンラインITスクール/education/00B4AC)の3社追加(672→675社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
