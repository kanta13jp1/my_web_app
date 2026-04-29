-- PS#4 S173: 競合3社追加 390→393社 (doodle/cal-com/hellosign)
-- SEO: "Doodle代替"/"Cal.com代替"/"HelloSign代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S173: 競合3社追加 390→393社 (doodle/cal-com/hellosign)',
  'comparison_page.dartにdoodle(日程調整/scheduling/00A67E)/cal-com(OSS予約/scheduling/111827)/hellosign(Dropbox電子署名/esign/0061FF)の3社追加(390→393社)。sitemap 436 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
