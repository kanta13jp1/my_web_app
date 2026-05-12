-- PS#4 S524: 競合3社追加 継続 (countly/smartlook/crazyegg)
-- SEO: "Countly代替"/"Smartlook代替"/"Crazy Egg代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S524: 競合3社追加 (countly/smartlook/crazyegg)',
  'comparison_page.dartにcountly(OSS モバイル/ウェブ分析・自社ホスト・GDPR準拠・プッシュ通知・リモートコンフィグ/3C3C3C)/smartlook(セッションレコーディング・ヒートマップ・ファネル分析・モバイルアプリ対応/E91E63)/crazyegg(ヒートマップ・スクロールマップ・A/Bテスト・セッション録画・LP最適化/FF4500)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
