-- PS#4 S165: 競合3社追加 366→369社 (brilliant/masterclass/make-com)
-- SEO: "Brilliant代替"/"MasterClass代替"/"Make代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S165: 競合3社追加 366→369社 (brilliant/masterclass/make-com)',
  'comparison_page.dartにbrilliant(数学・科学学習/learning/FF6B35)/masterclass(著名人動画講座/learning/1A1A1A)/make-com(ノーコード自動化/automation/6D00CC)の3社追加(366→369社)。sitemap 412 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
