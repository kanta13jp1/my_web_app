-- PS#4 S317: 競合3社追加 822→825社 (customer-io/neon-tech/convex-dev)
-- SEO: "Customer.io代替"/"Neon代替"/"Convex代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S317: 競合3社追加 822→825社 (customer-io/neon-tech/convex-dev)',
  'comparison_page.dartにcustomer-io(データ駆動オートメーションメールSMS/email-marketing/16A34A)/neon-tech(サーバーレスPostgreSQL ブランチング/db/00E5BF)/convex-dev(フルスタックTypeScript BaaS/db/EF4444)の3社追加(822→825社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
