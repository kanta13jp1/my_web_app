-- PS#4 S220: 競合3社追加 531→534社 (sendgrid/mailgun/postmark)
-- SEO: "SendGrid代替"/"Mailgun代替"/"Postmark代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S220: 競合3社追加 531→534社 (sendgrid/mailgun/postmark)',
  'comparison_page.dartにsendgrid(Twilioメール配信API/email-delivery/1A82E2)/mailgun(メール送受信API/email-delivery/CA2F27)/postmark(高配信率メール/email-delivery/FFCC00)の3社追加(531→534社)。sitemap 580 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
