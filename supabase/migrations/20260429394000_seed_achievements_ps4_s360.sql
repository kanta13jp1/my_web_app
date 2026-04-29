-- PS#4 S360: 競合3社追加 951→954社 (castr/dacast/uscreen)
-- SEO: "Castr代替"/"Dacast代替"/"Uscreen代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S360: 競合3社追加 951→954社 (castr/dacast/uscreen)',
  'comparison_page.dartにcastr(マルチストリーミングクラウドビデオホスティング/streaming/E91E8C)/dacast(プロライブストリーミングOTTマネタイズ/streaming/0B5394)/uscreen(OTT動画会員制定期課金プラットフォーム/video-monetize/8B5CF6)の3社追加(951→954社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
