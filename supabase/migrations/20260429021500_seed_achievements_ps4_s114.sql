-- PS#4 S114: 超高検索ボリューム競合3社追加 (hailuo/sendgrid/convertkit) 213→216社
-- SEO: "Hailuo AI代替"/"SendGrid代替"/"ConvertKit代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S114: 競合3社追加 213→216社 (hailuo/sendgrid/convertkit)',
  'comparison_page.dartにhailuo(Hailuo AI高品質AI動画生成/Kuaishou/無料~月額約10USD/ai-video)/sendgrid(Twilioメール配信API/無料~月額19.95USD/email-marketing)/convertkit(クリエイター向けメールマーケ/無料~月額9USD/newsletter)の3社追加(213→216社)。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記213→216統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
