-- PS#4 S312: 競合3社追加 807→810社 (totango/churnzero/vitally)
-- SEO: "Totango代替"/"ChurnZero代替"/"Vitally代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S312: 競合3社追加 807→810社 (totango/churnzero/vitally)',
  'comparison_page.dartにtotango(カスタマーサクセスチャーン防止/cs/6366F1)/churnzero(リアルタイムCS SaaS顧客維持/cs/06B6D4)/vitally(B2B SaaS向けCSプラットフォーム/cs/10B981)の3社追加(807→810社)。sitemap 859 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
