-- PS#4 S383: 競合3社追加 1020→1023社 (plausible/unity/nats)
-- SEO: "Plausible代替"/"Unity代替"/"NATS代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S383: 競合3社追加 1020→1023社 (plausible/unity/nats)',
  'comparison_page.dartにplausible(プライバシーファーストWebAnalyticsクッキー不要GDPR/analytics/5850EC)/unity(ゲームエンジンインタラクティブ3DリアルタイムAR/VR/game-engine/222222)/nats(クラウドネイティブメッセージング超軽量高スループット/messaging/27AAE1)の3社追加(1020→1023社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
