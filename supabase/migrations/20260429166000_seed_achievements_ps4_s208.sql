-- PS#4 S208: 競合3社追加 495→498社 (concur/expensify/ramp)
-- SEO: "Concur代替"/"Expensify代替"/"Ramp代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S208: 競合3社追加 495→498社 (concur/expensify/ramp)',
  'comparison_page.dartにconcur(SAP経費出張/expense/0070AD)/expensify(スマートスキャン経費/expense/00B2E3)/ramp(AI経費削減/expense/000000)の3社追加(495→498社)。sitemap 544 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
