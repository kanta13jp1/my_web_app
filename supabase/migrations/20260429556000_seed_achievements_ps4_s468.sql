-- PS#4 S468: 競合3社追加 1225→1228社 (adyen/braintree/razorpay)
-- SEO: "Adyen代替"/"Braintree代替"/"Razorpay代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S468: 競合3社追加 1225→1228社 (adyen/braintree/razorpay)',
  'comparison_page.dartにadyen(エンタープライズ決済100+方法オムニチャネル/0ABF53)/braintree(PayPal傘下決済API Venmo統合Vault/22A7F0)/razorpay(インド決済UPIネットバンキングPayroll/072654)の3社追加(1225→1228社)。sitemap 1327 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
