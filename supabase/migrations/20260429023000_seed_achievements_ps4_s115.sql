-- PS#4 S115: 超高検索ボリューム競合3社追加 (mailerlite/hotjar/amplitude) 216→219社
-- SEO: "MailerLite代替"/"Hotjar代替"/"Amplitude代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S115: 競合3社追加 216→219社 (mailerlite/hotjar/amplitude)',
  'comparison_page.dartにmailerlite(シンプルメールマーケ/無料~月額9USD/email-marketing)/hotjar(ヒートマップUX分析/無料~月額32USD/analytics)/amplitude(プロダクトアナリティクス/無料~月額49USD/analytics)の3社追加(216→219社)。新カテゴリanalytics追加。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記216→219統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
