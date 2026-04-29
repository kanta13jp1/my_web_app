-- PS#4 S177: 競合3社追加 402→405社 (hey/spark/front)
-- SEO: "Hey代替"/"Spark代替"/"Front代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S177: 競合3社追加 402→405社 (hey/spark/front)',
  'comparison_page.dartにhey(Basecamp革命メール/email/E63946)/spark(Readdle AIメール/email/E2462C)/front(チーム共有受信トレイ/email/F25F4C)の3社追加(402→405社)。sitemap 448 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
