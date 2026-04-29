-- PS#4 S469: 競合3社追加 1228→1231社 (klarna/afterpay/affirm)
-- SEO: "Klarna代替"/"Afterpay代替"/"Affirm代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S469: 競合3社追加 1228→1231社 (klarna/afterpay/affirm)',
  'comparison_page.dartにklarna(スウェーデンBNPL 4回分割Klarna Card AI価格比較/FFB3C7)/afterpay(Block傘下4回無利子250k+加盟店/B2FCE4)/affirm(透明ローン隠れ手数料なし0%APR Amazon統合/060809)の3社追加(1228→1231社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
