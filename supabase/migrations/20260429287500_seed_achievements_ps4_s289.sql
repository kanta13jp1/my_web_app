-- PS#4 S289: 競合3社追加 738→741社 (novu/courier/sendbird)
-- SEO: "Novu代替"/"Courier代替"/"Sendbird代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S289: 競合3社追加 738→741社 (novu/courier/sendbird)',
  'comparison_page.dartにnovu(OSS通知インフラマルチチャネル/notifications/30CF80)/courier(マルチチャネル通知APIプラットフォーム/notifications/5C42F5)/sendbird(アプリ内チャット通話AI会話API/chat/742DDD)の3社追加(738→741社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
