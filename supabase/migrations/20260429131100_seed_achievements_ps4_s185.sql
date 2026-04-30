-- PS#4 S185: 競合3社追加 426→429社 (carrd/unbounce/instapage)
-- SEO: "Carrd代替"/"Unbounce代替"/"Instapage代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S185: 競合3社追加 426→429社 (carrd/unbounce/instapage)',
  'comparison_page.dartにcarrd(1ページサイト/web/00AAFF)/unbounce(AI最適化LP/web/FFD140)/instapage(LP最適化PF/web/FF6B35)の3社追加(426→429社)。sitemap 472 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
