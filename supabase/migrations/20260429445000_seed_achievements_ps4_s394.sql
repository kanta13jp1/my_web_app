-- PS#4 S394: 競合3社追加 1006→1009社 (drift/qualified/chili-piper)
-- SEO: "Drift代替"/"Qualified代替"/"Chili Piper代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S394: 競合3社追加 1006→1009社 (drift/qualified/chili-piper)',
  'comparison_page.dartにdrift(AI会話型マーケティングセールスチャットリード育成/conversational-marketing/0063E0)/qualified(Salesforceネイティブ会話型マーケティングパイプライン/conversational-marketing/0B2267)/chili-piper(インバウンドリード即時予約会議スケジュール自動化/scheduling/FF4040)の3社追加(1006→1009社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
