-- PS#4 S392: 競合3社追加 1047→1050社 (tealium/attentive/clevertap)
-- SEO: "Tealium代替"/"Attentive代替"/"CleverTap代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S392: 競合3社追加 1047→1050社 (tealium/attentive/clevertap)',
  'comparison_page.dartにtealium(エンタープライズCDPタグ管理データ統合/cdp/0033A0)/attentive(SMSマーケティングeコマース会話型AI/sms-marketing/8A2BE2)/clevertap(モバイルエンゲージメントプッシュ通知分析/mobile-marketing/E63950)の3社追加(1047→1050社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
