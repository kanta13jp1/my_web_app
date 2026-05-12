-- PS#4 S195: 競合3社追加 456→459社 (expensify/ramp/brex)
-- SEO: "Expensify代替"/"Ramp代替"/"Brex代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S195: 競合3社追加 456→459社 (expensify/ramp/brex)',
  'comparison_page.dartにexpensify(経費精算/expense/0185FF)/ramp(法人カード無料/expense/2B2B2B)/brex(スタートアップ金融/expense/6C3AB8)の3社追加(456→459社)。sitemap 502 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
