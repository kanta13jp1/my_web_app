-- PS#4 S116: 超高検索ボリューム競合3社追加 (mixpanel/brevo/beehiiv) 219→222社
-- SEO: "Mixpanel代替"/"Brevo代替"/"beehiiv代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S116: 競合3社追加 219→222社 (mixpanel/brevo/beehiiv)',
  'comparison_page.dartにmixpanel(イベントベースプロダクトアナリティクス/無料~月額24USD/analytics)/brevo(旧Sendinblue/メール+SMS統合/無料~/email-marketing)/beehiiv(クリエイターニュースレター/無料~月額39USD/newsletter)の3社追加(219→222社)。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記219→222統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
