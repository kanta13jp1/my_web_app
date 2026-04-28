-- PS#4 S110: 超高検索ボリューム競合3社追加 (mailchimp/monday-com/freshdesk) 201→204社
-- SEO: "Mailchimp代替"/"Monday.com代替"/"Freshdesk代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S110: 競合3社追加 201→204社 (mailchimp/monday-com/freshdesk)',
  'comparison_page.dartにmailchimp(Eメールマーケティング/無料~月額13USD/email-marketing)/monday-com(チームプロジェクト管理/月額9USD~/project)/freshdesk(AIヘルプデスク/無料~月額15USD/support)の3社追加(201→204社)。新カテゴリemail-marketing追加。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記201→204統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
