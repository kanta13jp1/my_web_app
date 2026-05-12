-- PS#4 S294: 競合3社追加 753→756社 (dialpad/aircall/ringcentral)
-- SEO: "Dialpad代替"/"Aircall代替"/"RingCentral代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S294: 競合3社追加 753→756社 (dialpad/aircall/ringcentral)',
  'comparison_page.dartにdialpad(AIビジネス通話VoIPコンタクトセンター/voip/7C3AED)/aircall(クラウドビジネス電話CRM統合/voip/00BEA4)/ringcentral(UCaaS通話メッセージビデオ統合/voip/FF7D00)の3社追加(753→756社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
