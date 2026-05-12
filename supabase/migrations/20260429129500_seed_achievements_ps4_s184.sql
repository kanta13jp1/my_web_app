-- PS#4 S184: 競合3社追加 423→426社 (customerio/omnisend/moosend)
-- SEO: "Customer.io代替"/"Omnisend代替"/"Moosend代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S184: 競合3社追加 423→426社 (customerio/omnisend/moosend)',
  'comparison_page.dartにcustomerio(ビヘイビアーメッセージ/email/FD7B2F)/omnisend(EC SMS自動化/email/0B3D91)/moosend(格安メール自動化/email/2EB8E6)の3社追加(423→426社)。sitemap 469 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
