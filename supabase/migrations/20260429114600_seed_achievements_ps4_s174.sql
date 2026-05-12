-- PS#4 S174: 競合3社追加 393→396社 (intercom/zendesk/freshdesk)
-- SEO: "Intercom代替"/"Zendesk代替"/"Freshdesk代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S174: 競合3社追加 393→396社 (intercom/zendesk/freshdesk)',
  'comparison_page.dartにintercom(AI CS/support/1F8DED)/zendesk(チケット管理/support/03363D)/freshdesk(Zendesk代替/support/25C16F)の3社追加(393→396社)。sitemap 439 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
