-- PS#4 S182: 競合3社追加 417→420社 (flodesk/constant-contact/campaign-monitor)
-- SEO: "Flodesk代替"/"Constant Contact代替"/"Campaign Monitor代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S182: 競合3社追加 417→420社 (flodesk/constant-contact/campaign-monitor)',
  'comparison_page.dartにflodesk(クリエイターメール/email/E96F4A)/constant-contact(SMBマーケ/email/0065A3)/campaign-monitor(メール自動化/email/6DB33F)の3社追加(417→420社)。sitemap 463 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
