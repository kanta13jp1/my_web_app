-- PS#4 S358: 競合3社追加 945→948社 (screencastify/elgato/streamlabs)
-- SEO: "Screencastify代替"/"Elgato代替"/"Streamlabs代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S358: 競合3社追加 945→948社 (screencastify/elgato/streamlabs)',
  'comparison_page.dartにscreencastify(ブラウザ拡張画面録画教育向け/screen-record/4CAF50)/elgato(ストリーマー向けキャプチャカード配信機材/streaming-gear/101010)/streamlabs(ゲーム配信ライブアラートシステム/streaming/31C3A2)の3社追加(945→948社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
