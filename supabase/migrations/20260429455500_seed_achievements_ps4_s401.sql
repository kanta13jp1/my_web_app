-- PS#4 S401: 競合3社追加 1027→1030社 (smartlead/userinterviews/respondent)
-- SEO: "Smartlead代替"/"User Interviews代替"/"Respondent代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S401: 競合3社追加 1027→1030社 (smartlead/userinterviews/respondent)',
  'comparison_page.dartにsmartlead(マルチチャネルコールドアウトリーチメールウォームアップ自動化/sales-engagement/0EA5E9)/userinterviews(ユーザーリサーチ参加者リクルートメントUXパネル/ux-research/2DD4BF)/respondent(B2BプロフェッショナルUXリサーチ参加者マーケット/ux-research/FF6B35)の3社追加(1027→1030社)。sitemap 1120 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
