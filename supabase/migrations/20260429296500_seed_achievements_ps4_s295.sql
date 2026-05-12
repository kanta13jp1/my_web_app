-- PS#4 S295: 競合3社追加 756→759社 (chorus-ai/agorapulse/eclincher)
-- SEO: "Chorus代替"/"Agorapulse代替"/"eClincher代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S295: 競合3社追加 756→759社 (chorus-ai/agorapulse/eclincher)',
  'comparison_page.dartにchorus-ai(ZoomInfo会話インテリジェンスセールス通話分析/sales/036EC4)/agorapulse(SNS管理スケジュール受信トレイ/social/4C5AE8)/eclincher(SNS管理自動投稿エンゲージメント/social/2DD4BF)の3社追加(756→759社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
