-- PS#4 S127: 競合3社追加 252→255社 (google-meet/skype/adobe-xd)
-- SEO: "Google Meet代替"/"Skype代替"/"Adobe XD代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S127: 競合3社追加 252→255社 (google-meet/skype/adobe-xd)',
  'comparison_page.dartにgoogle-meet(Google統合ビデオ会議/video-comm/00897B)/skype(MicrosoftビデオIP電話/video-comm/00AFF0)/adobe-xd(UI/UXプロトタイピング/design/FF26BE)の3社追加(252→255社)。sitemap301URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
