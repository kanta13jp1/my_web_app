-- PS#4 S307: 競合3社追加 792→795社 (zillow/redfin/compass)
-- SEO: "Zillow代替"/"Redfin代替"/"Compass代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S307: 競合3社追加 792→795社 (zillow/redfin/compass)',
  'comparison_page.dartにzillow(米国不動産検索売買賃貸/proptech/006AFF)/redfin(低手数料テクノロジー不動産エージェント/proptech/CC1F00)/compass(テクノロジープレミアム不動産ブローカー/proptech/1A1A1A)の3社追加(792→795社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
