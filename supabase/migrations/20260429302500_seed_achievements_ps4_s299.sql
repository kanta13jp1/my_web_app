-- PS#4 S299: 競合3社追加 768→771社 (openphone/nextiva/justcall)
-- SEO: "OpenPhone代替"/"Nextiva代替"/"JustCall代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S299: 競合3社追加 768→771社 (openphone/nextiva/justcall)',
  'comparison_page.dartにopenphone(スタートアップ向けビジネス電話VoIP/voip/A957F5)/nextiva(中小企業向けUCaaS通信/voip/0099E6)/justcall(セールスサポートAIクラウド電話/voip/0EA5E9)の3社追加(768→771社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
