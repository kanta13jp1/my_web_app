-- PS#4 S264: 競合3社追加 663→666社 (adp/paychex/zenefits)
-- SEO: "ADP代替"/"Paychex代替"/"Zenefits代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S264: 競合3社追加 663→666社 (adp/paychex/zenefits)',
  'comparison_page.dartにadp(米国最大給与計算HR/hr/CC0000)/paychex(中小企業給与計算HR/hr/003087)/zenefits(クラウドHRプラットフォーム/hr/00D4AA)の3社追加(663→666社)。sitemap 673 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
